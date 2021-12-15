/// Implementation of RMRK NFT token specification (https://github.com/rmrk-team/rmrk-spec).
module Sender::RMRK {
    use Std::Signer;
    use Std::Vector;
    use Std::DiemBlock;
    use Std::Option::{Self, Option};

    const ERR_COLLECTION_ALREADY_EXISTS: u64 = 1;
    const ERR_COLLECTION_DOES_NOT_EXIST: u64 = 2;
    const ERR_COLLECTION_ISSUER_ALREADY_CHANGED: u64 = 4;
    const ERR_COLLECTION_NEW_ISSUER_INVALID: u64 = 6;
    const ERR_COLLECTION_ISSUER_NOT_CHANGED: u64 = 5;
    const ERR_CANNOT_ISSUE_NOT_PERMITTED: u64 = 3;

    const ERR_MAX_NUMBER_OF_COLLECTION_ITEMS_REACHED: u64 = 24;
    const ERR_COLLECTION_LOCKED: u64 = 25;
    const ERR_COLLECTION_IS_INVALID: u64 = 26;

    const ERR_NFT_STORAGE_DOES_NOT_EXIST: u64 = 11;
    const ERR_NFT_STORAGE_ALREADY_EXISTS: u64 = 12;

    const ERR_TOKEN_WITH_ID_DOES_NOT_EXIST: u64 = 44;
    const ERR_TOKEN_IS_NOT_TRANSFERRABLE: u64 = 45;

    struct Collection<phantom Type: store> has key {
        next_token_id: u64,
        pubkey_id: vector<u8>,
        max_items: u64,
        tokens_issued: u64,
        uri: vector<u8>,
        next_issuer: Option<address>,
        locked: bool,
    }

    struct NFT<Type: store + drop> has store, drop {
        collection_id: vector<u8>,
        id: u64,
        content: Type,
        uri: vector<u8>,
        transferable: u64,
    }

    struct NFTStorage<Type: store + drop> has key {
        tokens: vector<NFT<Type>>,
    }

    /// Implements CREATE interaction from RMRK 2.0.0 spec
    /// (https://github.com/rmrk-team/rmrk-spec/blob/master/standards/rmrk2.0.0/interactions/create.md)
    public fun create_collection<Type: store + drop>(
        issuer_acc: &signer,
        pubkey_id_with_symbol: vector<u8>,
        uri: vector<u8>,
        max_items: u64,
    ) {
        let issuer_addr = Signer::address_of(issuer_acc);
        assert(!exists<Collection<Type>>(issuer_addr), ERR_COLLECTION_ALREADY_EXISTS);

        let collection =
            Collection<Type>{
                next_token_id: 1,
                pubkey_id: pubkey_id_with_symbol,
                uri,
                max_items,
                tokens_issued: 0,
                next_issuer: Option::none(),
                locked: false,
            };
        move_to(issuer_acc, collection);
    }

    /// Part 1 of the implementation of CHANGEISSUER interaction from RMRK 2.0.0 spec
    /// (https://github.com/rmrk-team/rmrk-spec/blob/master/standards/rmrk2.0.0/interactions/changeissuer.md)
    ///
    /// Implementation consists of two parts:
    /// 1. Change Collection.next_issuer into the address of the new issuer with this method.
    /// 2. Accept change with transaction signed by the new issuer with `accept_collection_as_new_issuer`.
    public fun change_collection_issuer<Type: store + drop>(
        issuer_acc: &signer,
        new_issuer_addr: address
    ) acquires Collection {
        let issuer_addr = Signer::address_of(issuer_acc);
        assert(exists<Collection<Type>>(issuer_addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(issuer_addr);
        assert(Option::is_none(&collection.next_issuer), ERR_COLLECTION_ISSUER_ALREADY_CHANGED);

        collection.next_issuer = Option::some(new_issuer_addr);
    }

    /// Cancel CHANGEISSUER request, see `change_collection_issuer`.
    public fun cancel_collection_issuer_change<Type: store + drop>(issuer_acc: &signer) acquires Collection {
        let issuer_addr = Signer::address_of(issuer_acc);
        assert(exists<Collection<Type>>(issuer_addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(issuer_addr);
        assert(Option::is_some(&collection.next_issuer), ERR_COLLECTION_NEW_ISSUER_INVALID);

        collection.next_issuer = Option::none();
    }

    /// Part 2 of the implementation of CHANGEISSUER interaction from RMRK 2.0.0 spec
    /// (https://github.com/rmrk-team/rmrk-spec/blob/master/standards/rmrk2.0.0/interactions/changeissuer.md)
    /// See docs for the `change_collection_issuer` for the description.
    public fun accept_collection_as_new_issuer<Type: store + drop>(
        new_issuer_acc: &signer,
        old_issuer_addr: address
    ) acquires Collection {
        assert(exists<Collection<Type>>(old_issuer_addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = move_from<Collection<Type>>(old_issuer_addr);
        assert(Option::is_some(&collection.next_issuer), ERR_COLLECTION_ISSUER_NOT_CHANGED);

        let new_issuer_addr = Signer::address_of(new_issuer_acc);
        assert(Option::contains(&collection.next_issuer, &new_issuer_addr), ERR_COLLECTION_NEW_ISSUER_INVALID);

        collection.next_issuer = Option::none();
        move_to(new_issuer_acc, collection);
    }

    public fun lock_collection<Type: store + drop>(issuer_acc: &signer) acquires Collection {
        let issuer_addr = Signer::address_of(issuer_acc);
        assert(exists<Collection<Type>>(issuer_addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(issuer_addr);
        collection.locked = true;
    }

    public fun create_nft_storage<Type: store + drop>(owner_acc: &signer) {
        let owner_addr = Signer::address_of(owner_acc);
        assert(!exists<NFTStorage<Type>>(owner_addr), ERR_NFT_STORAGE_ALREADY_EXISTS);

        let storage = NFTStorage<Type>{ tokens: Vector::empty() };
        move_to(owner_acc, storage);
    }

    public fun mint_token<Type: store + drop>(
        issuer_acc: &signer,
        content: Type,
        uri: vector<u8>,
        transferable: u64,
        owner_addr: address
    ): u64 acquires Collection, NFTStorage {
        let addr = Signer::address_of(issuer_acc);
        assert(exists<Collection<Type>>(addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(addr);
        assert(!collection.locked, ERR_COLLECTION_LOCKED);

        let tokens_issued = collection.tokens_issued;
        assert(
            is_infinite_items_allowed(collection) || tokens_issued < collection.max_items,
            ERR_MAX_NUMBER_OF_COLLECTION_ITEMS_REACHED
        );

        let token_id = collection.next_token_id;
        collection.next_token_id = collection.next_token_id + 1;
        collection.tokens_issued = tokens_issued + 1;

        let collection_id = *&collection.pubkey_id;
        let nft = NFT<Type>{ collection_id: copy collection_id, id: token_id, content, uri, transferable };

        add_nft_to_storage(nft, owner_addr);
        token_id
    }

    public fun send_token_to_account<Type: store + drop>(
        owner_acc: &signer,
        token_id: u64,
        recipient_addr: address
    ) acquires NFTStorage {
        let owner_addr = Signer::address_of(owner_acc);
        assert(exists<NFTStorage<Type>>(owner_addr), ERR_NFT_STORAGE_DOES_NOT_EXIST);
        assert(exists<NFTStorage<Type>>(recipient_addr), ERR_NFT_STORAGE_DOES_NOT_EXIST);

        let owner_storage = borrow_global_mut<NFTStorage<Type>>(owner_addr);
        let nft = remove_nft_by_id(owner_storage, token_id);

        assert(is_transferrable(&nft), ERR_TOKEN_IS_NOT_TRANSFERRABLE);
        add_nft_to_storage(nft, recipient_addr);
    }

    public fun burn_token<Type: store + drop>(
        owner_acc: &signer,
        token_id: u64,
        collection_issuer_addr: address
    ) acquires NFTStorage, Collection {
        let owner_addr = Signer::address_of(owner_acc);
        assert(exists<NFTStorage<Type>>(owner_addr), ERR_NFT_STORAGE_DOES_NOT_EXIST);

        let storage = borrow_global_mut<NFTStorage<Type>>(owner_addr);
        let nft = remove_nft_by_id(storage, token_id);

        assert(exists<Collection<Type>>(collection_issuer_addr), ERR_COLLECTION_DOES_NOT_EXIST);
        let collection =
            borrow_global_mut<Collection<Type>>(collection_issuer_addr);
        assert(*&collection.pubkey_id == *&nft.collection_id, ERR_COLLECTION_IS_INVALID);
        collection.tokens_issued = collection.tokens_issued - 1;
    }

    fun is_infinite_items_allowed<Type: store + drop>(collection: &Collection<Type>): bool {
        collection.max_items == 0
    }

    fun is_transferrable<Type: store + drop>(nft: &NFT<Type>): bool {
        nft.transferable != 0 && nft.transferable <= DiemBlock::get_current_block_height()
    }

    fun add_nft_to_storage<Type: store + drop>(nft: NFT<Type>, storage_owner_addr: address) acquires NFTStorage {
        assert(
            exists<NFTStorage<Type>>(storage_owner_addr),
            ERR_NFT_STORAGE_DOES_NOT_EXIST
        );
        let owner_nft_storage = borrow_global_mut<NFTStorage<Type>>(storage_owner_addr);
        Vector::push_back(&mut owner_nft_storage.tokens, nft);
    }

    fun remove_nft_by_id<Type: store + drop>(
        storage: &mut NFTStorage<Type>,
        token_id: u64
    ): NFT<Type> {
        let tokens = &mut storage.tokens;
        let i = 0;
        while (i < Vector::length(tokens)) {
            if (Vector::borrow(tokens, i).id == token_id) {
                return Vector::swap_remove(tokens, i)
            };
            i = i + 1;
        };
        abort ERR_TOKEN_WITH_ID_DOES_NOT_EXIST
    }

    #[test_only]
    public fun get_number_of_tokens_minted<Type: store + drop>(issuer_acc: &signer): u64 acquires Collection {
        let addr = Signer::address_of(issuer_acc);
        assert(exists<Collection<Type>>(addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(addr);
        collection.tokens_issued
    }

    #[test_only]
    public fun collection_exists<Type: store + drop>(issuer_addr: address): bool {
        exists<Collection<Type>>(issuer_addr)
    }

    #[test_only]
    public fun token_exists<Type: store + drop>(owner_addr: address): bool acquires NFTStorage {
        let storage = borrow_global_mut<NFTStorage<Type>>(owner_addr);
        Vector::length(&storage.tokens) != 0
    }
}



















