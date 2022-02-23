/// Implementation of RMRK NFT token specification (https://github.com/rmrk-team/rmrk-spec).
module Sender::RMRK {
    use Std::Signer;
    use Std::Vector;
    use Std::ASCII::String;
    use PontemFramework::PontBlock;
    use Std::Event;
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

    const ERR_NFT_WALLET_DOES_NOT_EXIST: u64 = 11;
    const ERR_NFT_WALLET_ALREADY_EXISTS: u64 = 12;

    const ERR_TOKEN_WITH_ID_DOES_NOT_EXIST: u64 = 44;
    const ERR_TOKEN_IS_NOT_TRANSFERRABLE: u64 = 45;

    const ERR_PARENT_NFT_IS_SET: u64 = 51;
    const ERR_PARENT_NFT_IS_NOT_SET: u64 = 52;
    const ERR_PARENT_NFT_IS_DIFFERENT: u64 = 53;
    const ERR_CHILD_NFT_DOES_NOT_EXIST: u64 = 54;

    struct Collection<phantom Type: store> has key {
        next_token_id: u64,
        pubkey_id: String,
        uri: String,
        max_items: u64,
        tokens_issued: u64,
        next_issuer: Option<address>,
        locked: bool,
    }

    struct NFT<Type: store + drop> has store, drop {
        collection_pubkey_id: String,
        id: u64,
        content: Type,
        transferrable: u64,
        parent_nft_id: Option<u64>,
        children_nft_ids: vector<u64>,
    }

    /// Used to pack pair of (id, address) into a single entity to find NFT in the chain.
    struct NFTChainIdent has copy, drop {
        id: u64,
        owner_acc_address: address
    }

    struct NFTWallet<Type: store + drop> has key {
        nfts: vector<NFT<Type>>,
    }

    /// Perform an initialization steps for the future issuer of collections.
    public fun initialize_issuer<Type: store + drop>(issuer_acc: &signer) {
        move_to(issuer_acc, IssuerAccount<Type>{
            create_collection_events: Event::new_event_handle(issuer_acc),
            request_change_issuer_events: Event::new_event_handle(issuer_acc),
            cancel_change_issuer_events: Event::new_event_handle(issuer_acc),
            accept_change_issuer_events: Event::new_event_handle(issuer_acc),
            change_issuer_events: Event::new_event_handle(issuer_acc),
            lock_collection_events: Event::new_event_handle(issuer_acc)
        });
    }

    /// Implements CREATE interaction from RMRK 2.0.0 spec
    /// (https://github.com/rmrk-team/rmrk-spec/blob/master/standards/rmrk2.0.0/interactions/create.md)
    public fun create_collection<Type: store + drop>(
        issuer_acc: &signer,
        pubkey_id_with_symbol: String,
        uri: String,
        max_items: u64,
    ) acquires IssuerAccount {
        let issuer_addr = Signer::address_of(issuer_acc);
        assert!(!exists<Collection<Type>>(issuer_addr), ERR_COLLECTION_ALREADY_EXISTS);

        let collection =
            Collection<Type>{
                next_token_id: 1,
                pubkey_id: copy pubkey_id_with_symbol,
                uri: copy uri,
                max_items,
                tokens_issued: 0,
                next_issuer: Option::none(),
                locked: false,
            };
        move_to(issuer_acc, collection);
        Event::emit_event(
            &mut borrow_global_mut<IssuerAccount<Type>>(issuer_addr).create_collection_events,
            CreateCollectionEvent<Type>{
                pubkey_id: pubkey_id_with_symbol,
                uri,
                issuer: issuer_addr,
                max_items
            });
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
    ) acquires Collection, IssuerAccount {
        let issuer_addr = Signer::address_of(issuer_acc);
        assert!(exists<Collection<Type>>(issuer_addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(issuer_addr);
        assert!(Option::is_none(&collection.next_issuer), ERR_COLLECTION_ISSUER_ALREADY_CHANGED);

        collection.next_issuer = Option::some(new_issuer_addr);

        let pubkey_id = *&collection.pubkey_id;
        Event::emit_event(
            &mut borrow_global_mut<IssuerAccount<Type>>(issuer_addr).request_change_issuer_events,
            RequestChangeIssuerEvent<Type>{
                pubkey_id: copy pubkey_id,
                old_issuer: issuer_addr,
                new_issuer: new_issuer_addr,
            }
        );
    }

    /// Cancel CHANGEISSUER request, see `change_collection_issuer`.
    public fun cancel_collection_issuer_change<Type: store + drop>(issuer_acc: &signer) acquires Collection, IssuerAccount {
        let issuer_addr = Signer::address_of(issuer_acc);
        assert!(exists<Collection<Type>>(issuer_addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(issuer_addr);
        assert!(Option::is_some(&collection.next_issuer), ERR_COLLECTION_NEW_ISSUER_INVALID);

        let new_issuer = *Option::borrow(&collection.next_issuer);
        collection.next_issuer = Option::none();

        let pubkey_id = *&collection.pubkey_id;
        Event::emit_event(
            &mut borrow_global_mut<IssuerAccount<Type>>(issuer_addr).cancel_change_issuer_events,
            CancelChangeIssuerEvent<Type>{
                pubkey_id: copy pubkey_id,
                old_issuer: issuer_addr,
                new_issuer,
            }
        );
    }

    /// Part 2 of the implementation of CHANGEISSUER interaction from RMRK 2.0.0 spec
    /// (https://github.com/rmrk-team/rmrk-spec/blob/master/standards/rmrk2.0.0/interactions/changeissuer.md)
    /// See docs for the `change_collection_issuer` for the description.
    public fun accept_collection_as_new_issuer<Type: store + drop>(
        new_issuer_acc: &signer,
        old_issuer_addr: address
    ) acquires Collection, IssuerAccount {
        assert!(exists<Collection<Type>>(old_issuer_addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = move_from<Collection<Type>>(old_issuer_addr);
        assert!(Option::is_some(&collection.next_issuer), ERR_COLLECTION_ISSUER_NOT_CHANGED);

        let new_issuer_addr = Signer::address_of(new_issuer_acc);
        assert!(Option::contains(&collection.next_issuer, &new_issuer_addr), ERR_COLLECTION_NEW_ISSUER_INVALID);
        let pubkey_id = *&collection.pubkey_id;

        collection.next_issuer = Option::none();
        move_to(new_issuer_acc, collection);

        Event::emit_event(
            &mut borrow_global_mut<IssuerAccount<Type>>(old_issuer_addr).accept_change_issuer_events,
            AcceptChangeIssuerEvent<Type>{
                pubkey_id: copy pubkey_id,
                old_issuer: old_issuer_addr,
                new_issuer: new_issuer_addr,
            }
        );
        Event::emit_event(
            &mut borrow_global_mut<IssuerAccount<Type>>(new_issuer_addr).change_issuer_events,
            ChangeIssuerEvent<Type>{
                pubkey_id: copy pubkey_id,
                old_issuer: old_issuer_addr,
                new_issuer: new_issuer_addr,
            }
        );
    }

    /// COLLECTION LOCK: disables issuance of new NFT tokens in this collection. Irreversible.
    public fun lock_collection<Type: store + drop>(issuer_acc: &signer) acquires Collection, IssuerAccount {
        let issuer_addr = Signer::address_of(issuer_acc);
        assert!(exists<Collection<Type>>(issuer_addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(issuer_addr);
        collection.locked = true;

        let pubkey_id = *&collection.pubkey_id;
        Event::emit_event(
            &mut borrow_global_mut<IssuerAccount<Type>>(issuer_addr).lock_collection_events,
            LockCollectionEvent<Type>{
                pubkey_id: copy pubkey_id,
                issuer: issuer_addr,
            }
        );
    }

    /// Creates new NFT Wallet of `Type`. Requires &signer.
    public fun create_nft_wallet<Type: store + drop>(owner_acc: &signer) {
        let owner_addr = Signer::address_of(owner_acc);
        assert!(!exists<NFTWallet<Type>>(owner_addr), ERR_NFT_WALLET_ALREADY_EXISTS);

        let wallet = NFTWallet<Type>{ nfts: Vector::empty() };
        move_to(owner_acc, wallet);
    }

    /// NFT MINT: mints new NFT for the specified content `Type`.
    public fun mint_nft<Type: store + drop>(issuer_acc: &signer, content: Type, transferrable: u64): NFT<Type>
    acquires Collection {
        let addr = Signer::address_of(issuer_acc);
        assert!(exists<Collection<Type>>(addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(addr);
        assert!(!collection.locked, ERR_COLLECTION_LOCKED);

        let tokens_issued = collection.tokens_issued;
        assert!(
            is_infinite_items_allowed(collection) || tokens_issued < collection.max_items,
            ERR_MAX_NUMBER_OF_COLLECTION_ITEMS_REACHED
        );

        let token_id = collection.next_token_id;
        collection.next_token_id = collection.next_token_id + 1;
        collection.tokens_issued = tokens_issued + 1;

        let collection_pubkey_id = *&collection.pubkey_id;
        let nft = NFT<Type>{
            collection_pubkey_id: copy collection_pubkey_id,
            id: token_id,
            content,
            transferrable,
            parent_nft_id: Option::none(),
            children_nft_ids: Vector::empty(),
        };
        nft
    }

    public fun add_nft_to_wallet<Type: store + drop>(nft: NFT<Type>, wallet_owner_addr: address)
    acquires NFTWallet {
        assert!(
            exists<NFTWallet<Type>>(wallet_owner_addr),
            ERR_NFT_WALLET_DOES_NOT_EXIST
        );
        let wallet = borrow_global_mut<NFTWallet<Type>>(wallet_owner_addr);
        Vector::push_back(&mut wallet.nfts, nft);
    }

    /// Creates parent-child relationship between two NFTs.
    public fun set_parent_nft<Type: store + drop>(child_nft_ident: NFTChainIdent, parent_nft_ident: NFTChainIdent)
    acquires NFTWallet {
        set_child_nft_parent_id<Type>(copy child_nft_ident, Option::some(parent_nft_ident.id));

        let NFTChainIdent{ id, owner_acc_address } = parent_nft_ident;
        assert!(
            exists<NFTWallet<Type>>(owner_acc_address),
            ERR_NFT_WALLET_DOES_NOT_EXIST
        );
        let owner_wallet = borrow_global_mut<NFTWallet<Type>>(owner_acc_address);
        let wallet_nfts = &mut owner_wallet.nfts;
        let i = find_nft_index(wallet_nfts, id);
        let parent_nft = Vector::borrow_mut(wallet_nfts, i);

        Vector::push_back(&mut parent_nft.children_nft_ids, child_nft_ident.id);
    }

    /// Destroys parent-child relationship between two NFTs.
    public fun unset_parent_nft<Type: store + drop>(child_nft_ident: NFTChainIdent, parent_nft_ident: NFTChainIdent)
    acquires NFTWallet {
        set_child_nft_parent_id<Type>(copy child_nft_ident, Option::none());

        let NFTChainIdent{ id: parent_id, owner_acc_address: parent_owner_addr } = parent_nft_ident;
        assert!(
            exists<NFTWallet<Type>>(parent_owner_addr),
            ERR_NFT_WALLET_DOES_NOT_EXIST
        );
        let owner_wallet = borrow_global_mut<NFTWallet<Type>>(parent_owner_addr);
        let i = find_nft_index(&owner_wallet.nfts, parent_id);
        let parent_nft = Vector::borrow_mut(&mut owner_wallet.nfts, i);

        let (child_exists, i) = Vector::index_of(&parent_nft.children_nft_ids, &child_nft_ident.id);
        assert!(child_exists, ERR_CHILD_NFT_DOES_NOT_EXIST);
        Vector::swap_remove(&mut parent_nft.children_nft_ids, i);
    }

    public fun children<Type: store + drop>(parent_nft_ident: NFTChainIdent): vector<u64>
    acquires NFTWallet {
        let NFTChainIdent{ id: nft_id, owner_acc_address: owner_addr } = parent_nft_ident;
        assert!(
            exists<NFTWallet<Type>>(owner_addr),
            ERR_NFT_WALLET_DOES_NOT_EXIST
        );
        let owner_wallet = borrow_global_mut<NFTWallet<Type>>(owner_addr);
        let i = find_nft_index(&owner_wallet.nfts, nft_id);
        let parent_nft = Vector::borrow_mut(&mut owner_wallet.nfts, i);
        *&parent_nft.children_nft_ids
    }

    /// Creates pair of (nft_id, nft_owner_account_address) to find it on chain.
    public fun nft_chain_ident(id: u64, owner_acc_address: address): NFTChainIdent {
        NFTChainIdent{ id, owner_acc_address }
    }

    /// NFT SEND: send NFT from `owner_acc` to `recipient_addr`.
    public fun send_token_to_account<Type: store + drop>(owner_acc: &signer, token_id: u64, recipient_addr: address)
    acquires NFTWallet {
        let owner_addr = Signer::address_of(owner_acc);
        assert!(exists<NFTWallet<Type>>(owner_addr), ERR_NFT_WALLET_DOES_NOT_EXIST);
        assert!(exists<NFTWallet<Type>>(recipient_addr), ERR_NFT_WALLET_DOES_NOT_EXIST);

        let owner_wallet = borrow_global_mut<NFTWallet<Type>>(owner_addr);
        let nft = remove_nft_by_id(owner_wallet, token_id);

        assert!(is_transferrable(&nft), ERR_TOKEN_IS_NOT_TRANSFERRABLE);
        add_nft_to_wallet(nft, recipient_addr);
    }

    /// NFT BURN: destroys NFT with id `token_id` at the account `owner_acc`.
    /// Requires address of the current collection owner.
    public fun burn_token<Type: store + drop>(owner_acc: &signer, token_id: u64, collection_issuer_addr: address)
    acquires NFTWallet, Collection {
        let owner_addr = Signer::address_of(owner_acc);
        assert!(exists<NFTWallet<Type>>(owner_addr), ERR_NFT_WALLET_DOES_NOT_EXIST);

        let wallet = borrow_global_mut<NFTWallet<Type>>(owner_addr);
        let nft = remove_nft_by_id(wallet, token_id);

        assert!(exists<Collection<Type>>(collection_issuer_addr), ERR_COLLECTION_DOES_NOT_EXIST);
        let collection =
            borrow_global_mut<Collection<Type>>(collection_issuer_addr);
        assert!(*&collection.pubkey_id == *&nft.collection_pubkey_id, ERR_COLLECTION_IS_INVALID);
        collection.tokens_issued = collection.tokens_issued - 1;
    }

    fun set_child_nft_parent_id<Type: store + drop>(child_nft_ident: NFTChainIdent, parent_id: Option<u64>)
    acquires NFTWallet {
        let NFTChainIdent{ id: child_id, owner_acc_address: child_owner_addr } = child_nft_ident;
        assert!(
            exists<NFTWallet<Type>>(child_owner_addr),
            ERR_NFT_WALLET_DOES_NOT_EXIST
        );
        let owner_wallet = borrow_global_mut<NFTWallet<Type>>(child_owner_addr);
        let wallet_nfts = &mut owner_wallet.nfts;
        let i = find_nft_index(wallet_nfts, child_id);
        let child_nft = Vector::borrow_mut(wallet_nfts, i);

        if (Option::is_none(&parent_id)) {
            assert!(Option::is_some(&child_nft.parent_nft_id), ERR_PARENT_NFT_IS_NOT_SET);
        } else {
            assert!(Option::is_none(&child_nft.parent_nft_id), ERR_PARENT_NFT_IS_SET)
        };
        child_nft.parent_nft_id = parent_id;
    }

    fun is_infinite_items_allowed<Type: store + drop>(collection: &Collection<Type>): bool {
        collection.max_items == 0
    }

    fun is_transferrable<Type: store + drop>(nft: &NFT<Type>): bool {
        nft.transferrable != 0 && nft.transferrable <= PontBlock::get_current_block_height()
    }

    fun find_nft_index<Type: store + drop>(tokens: &vector<NFT<Type>>, id: u64): u64 {
        let i = 0;
        while (i < Vector::length(tokens)) {
            if (Vector::borrow(tokens, i).id == id) {
                return i
            };
            i = i + 1;
        };
        abort ERR_TOKEN_WITH_ID_DOES_NOT_EXIST
    }

    fun borrow_mut_nft_by_id<Type: store + drop>(wallet: &mut NFTWallet<Type>, id: u64): &mut NFT<Type> {
        let i = find_nft_index(&wallet.nfts, id);
        Vector::borrow_mut(&mut wallet.nfts, i)
    }

    fun remove_nft_by_id<Type: store + drop>(wallet: &mut NFTWallet<Type>, id: u64): NFT<Type> {
        let i = find_nft_index(&wallet.nfts, id);
        Vector::swap_remove(&mut wallet.nfts, i)
    }

    #[test_only]
    public fun get_nft_id<Type: store + drop>(nft: &NFT<Type>): u64 { nft.id }

    #[test_only]
    public fun get_number_of_tokens_minted<Type: store + drop>(issuer_acc: &signer): u64 acquires Collection {
        let addr = Signer::address_of(issuer_acc);
        assert!(exists<Collection<Type>>(addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(addr);
        collection.tokens_issued
    }

    #[test_only]
    public fun collection_exists<Type: store + drop>(issuer_addr: address): bool {
        exists<Collection<Type>>(issuer_addr)
    }

    #[test_only]
    public fun token_exists<Type: store + drop>(owner_addr: address): bool acquires NFTWallet {
        let wallet = borrow_global_mut<NFTWallet<Type>>(owner_addr);
        Vector::length(&wallet.nfts) != 0
    }

    struct IssuerAccount<phantom Type> has key {
        create_collection_events: Event::EventHandle<CreateCollectionEvent<Type>>,
        change_issuer_events: Event::EventHandle<ChangeIssuerEvent<Type>>,
        request_change_issuer_events: Event::EventHandle<RequestChangeIssuerEvent<Type>>,
        accept_change_issuer_events: Event::EventHandle<AcceptChangeIssuerEvent<Type>>,
        cancel_change_issuer_events: Event::EventHandle<CancelChangeIssuerEvent<Type>>,
        lock_collection_events: Event::EventHandle<LockCollectionEvent<Type>>,
    }

    struct CreateCollectionEvent<phantom Type> has store, drop {
        pubkey_id: String,
        uri: String,
        issuer: address,
        max_items: u64,
    }

    struct RequestChangeIssuerEvent<phantom Type> has store, drop {
        pubkey_id: String,
        old_issuer: address,
        new_issuer: address,
    }

    struct AcceptChangeIssuerEvent<phantom Type> has store, drop {
        pubkey_id: String,
        old_issuer: address,
        new_issuer: address,
    }

    struct CancelChangeIssuerEvent<phantom Type> has store, drop {
        pubkey_id: String,
        old_issuer: address,
        new_issuer: address,
    }

    struct ChangeIssuerEvent<phantom Type> has store, drop {
        pubkey_id: String,
        old_issuer: address,
        new_issuer: address,
    }

    struct LockCollectionEvent<phantom Type> has store, drop {
        pubkey_id: String,
        issuer: address,
    }
}



















