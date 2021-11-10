module Sender::RMRK {
    use Std::Signer;
    use Std::Vector;

    const ERR_COLLECTION_IS_ALREADY_EXISTS: u64 = 1;
    const ERR_COLLECTION_DOES_NOT_EXIST: u64 = 2;
    const ERR_CANNOT_ISSUE_NOT_PERMITTED: u64 = 3;

    struct Collection<Type: store> has key {
        token_counter: u64,
        // ASCII
        pubkey_id: vector<u8>,
        vacant_nfts: vector<VacantNFT<Type>>
    }

    struct VacantNFT<Type: store> has store {
        id: u64,
        content: Type,
        owner_addr: address,
    }

    struct NFT<Type: store> has key {
        collection_id: vector<u8>,
        id: u64,
        content: Type,
    }

    public fun create_collection<Type: store>(
        issuer_acc: &signer,
        pubkey_id_with_symbol: vector<u8>
    ) {
        let issuer_addr = Signer::address_of(issuer_acc);
        assert(!exists<Collection<Type>>(issuer_addr), ERR_COLLECTION_IS_ALREADY_EXISTS);

        let collection =
            Collection<Type> { token_counter: 0, pubkey_id: pubkey_id_with_symbol, vacant_nfts: Vector::empty() };
        move_to(issuer_acc, collection);
    }

    //    public fun change_issuer<Type: store>() {
    //
    //    }

    public fun mint_token<Type: store>(
        issuer_acc: &signer,
        content: Type,
        owner_addr: address
    ) acquires Collection {
        let addr = Signer::address_of(issuer_acc);
        assert(exists<Collection<Type>>(addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(addr);
        let token_id = collection.token_counter;
        collection.token_counter = token_id + 1;

        let vacant_nft = VacantNFT<Type> { id: token_id, content, owner_addr };
        Vector::push_back(&mut collection.vacant_nfts, vacant_nft);
    }

    public fun accept_token<Type: store>(owner_acc: &signer, issuer_addr: address) acquires Collection {
        let owner_addr = Signer::address_of(owner_acc);
        let collection = borrow_global_mut<Collection<Type>>(issuer_addr);
        let i = 0;
        while (i < Vector::length(&collection.vacant_nfts)) {
            let vacant_nft_ref = Vector::borrow(&collection.vacant_nfts, i);
            if (vacant_nft_ref.owner_addr == owner_addr) {
                let vacant_nft = Vector::swap_remove(&mut collection.vacant_nfts, i);
                let VacantNFT<Type> { id, content, owner_addr: _ } = vacant_nft;

                let pubkey_id = *&collection.pubkey_id;
                let nft = NFT { collection_id: (copy pubkey_id), id, content };
                move_to(owner_acc, nft);
                break
            }
        }
    }

    #[test_only]
    public fun get_number_of_tokens_minted<Type: store>(issuer_acc: &signer): u64 acquires Collection {
        let addr = Signer::address_of(issuer_acc);
        assert(exists<Collection<Type>>(addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(addr);
        collection.token_counter
    }

    #[test_only]
    public fun get_number_of_tokens_vacant<Type: store>(issuer_acc: &signer): u64 acquires Collection {
        let addr = Signer::address_of(issuer_acc);
        assert(exists<Collection<Type>>(addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global<Collection<Type>>(addr);
        Vector::length(&collection.vacant_nfts)
    }

    #[test_only]
    public fun accepted_token_exists<Type: store>(owner_addr: address): bool {
        exists<NFT<Type>>(owner_addr)
    }
}



















