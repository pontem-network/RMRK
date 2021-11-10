module Sender::RMRK {
    use Std::Signer;
    use Std::Vector;
    use Std::Option::{Self, Option};

    const ERR_COLLECTION_IS_ALREADY_EXISTS: u64 = 1;
    const ERR_COLLECTION_DOES_NOT_EXIST: u64 = 2;
    const ERR_COLLECTION_ISSUER_ALREADY_CHANGED: u64 = 4;
    const ERR_COLLECTION_NEW_ISSUER_INVALID: u64 = 6;
    const ERR_COLLECTION_ISSUER_NOT_CHANGED: u64 = 5;
    const ERR_CANNOT_ISSUE_NOT_PERMITTED: u64 = 3;

    const ERR_NFT_STORAGE_DOES_NOT_EXIST: u64 = 11;
    const ERR_NFT_STORAGE_ALREADY_EXISTS: u64 = 12;

    struct Collection<phantom Type: store> has key {
        token_counter: u64,
        // ASCII
        pubkey_id: vector<u8>,
        next_issuer: Option<address>,
    }

    struct NFT<Type: store> has store {
        collection_id: vector<u8>,
        id: u64,
        content: Type,
    }

    struct NFTStorage<Type: store> has key {
        tokens: vector<NFT<Type>>,
    }

    public fun create_collection<Type: store>(
        issuer_acc: &signer,
        pubkey_id_with_symbol: vector<u8>
    ) {
        let issuer_addr = Signer::address_of(issuer_acc);
        assert(!exists<Collection<Type>>(issuer_addr), ERR_COLLECTION_IS_ALREADY_EXISTS);

        let collection =
            Collection<Type> {
                token_counter: 0,
                pubkey_id: pubkey_id_with_symbol,
                next_issuer: Option::none()
            };
        move_to(issuer_acc, collection);
    }

    public fun change_collection_issuer<Type: store>(
        issuer_acc: &signer,
        new_issuer_addr: address
    ) acquires Collection {
        let issuer_addr = Signer::address_of(issuer_acc);
        assert(exists<Collection<Type>>(issuer_addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(issuer_addr);
        assert(Option::is_none(&collection.next_issuer), ERR_COLLECTION_ISSUER_ALREADY_CHANGED);

        collection.next_issuer = Option::some(new_issuer_addr);
    }

    public fun accept_collection_as_new_issuer<Type: store>(
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

    public fun create_nft_storage<Type: store>(owner_acc: &signer) {
        let owner_addr = Signer::address_of(owner_acc);
        assert(!exists<NFTStorage<Type>>(owner_addr), ERR_NFT_STORAGE_ALREADY_EXISTS);

        let storage = NFTStorage<Type> { tokens: Vector::empty() };
        move_to(owner_acc, storage);
    }

    public fun mint_token<Type: store>(
        issuer_acc: &signer,
        content: Type,
        owner_addr: address
    ) acquires Collection, NFTStorage {
        let addr = Signer::address_of(issuer_acc);
        assert(exists<Collection<Type>>(addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(addr);
        let token_id = collection.token_counter;
        collection.token_counter = token_id + 1;

        let collection_id = *&collection.pubkey_id;
        let nft = NFT<Type> { collection_id: copy collection_id, id: token_id, content };

        assert(exists<NFTStorage<Type>>(owner_addr), ERR_NFT_STORAGE_DOES_NOT_EXIST);
        let owner_nft_storage = borrow_global_mut<NFTStorage<Type>>(owner_addr);
        Vector::push_back(&mut owner_nft_storage.tokens, nft);
    }

    #[test_only]
    public fun get_number_of_tokens_minted<Type: store>(issuer_acc: &signer): u64 acquires Collection {
        let addr = Signer::address_of(issuer_acc);
        assert(exists<Collection<Type>>(addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(addr);
        collection.token_counter
    }

    #[test_only]
    public fun collection_exists<Type: store>(issuer_addr: address): bool {
        exists<Collection<Type>>(issuer_addr)
    }

    #[test_only]
    public fun token_exists<Type: store>(owner_addr: address): bool acquires NFTStorage {
        let storage = borrow_global_mut<NFTStorage<Type>>(owner_addr);
        Vector::length(&storage.tokens) != 0
    }
}



















