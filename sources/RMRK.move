module Sender::RMRK {
    use Std::Signer;
//    use Std::Vector;

    const ERR_COLLECTION_IS_ALREADY_EXISTS: u64 = 1;
    const ERR_COLLECTION_DOES_NOT_EXIST: u64 = 2;
    const ERR_CANNOT_ISSUE_NOT_PERMITTED: u64 = 3;

    struct Collection<phantom Type> has key {
        token_counter: u64,
//        issuer: address,
        // ASCII
        pubkey_id: vector<u8>,
        // ASCII
        //        symbol: Sym,
        //        guid_generator: Generator,
    }

    struct NFT<Type: store> has key {
        collection_id: vector<u8>,
        id: u64,
        content: Type
    }

    public fun create_collection<Type: store>(
        issuer_acc: &signer,
        pubkey_id_with_symbol: vector<u8>
    ) {
        let issuer_addr = Signer::address_of(issuer_acc);
        assert(!exists<Collection<Type>>(issuer_addr), ERR_COLLECTION_IS_ALREADY_EXISTS);

        let collection =
            Collection<Type> { token_counter: 0, pubkey_id: pubkey_id_with_symbol };
        move_to(issuer_acc, collection);
    }

//    public fun change_issuer<Type: store>() {
//
//    }

    public fun mint_token<Type: store>(issuer_acc: &signer, content: Type) acquires Collection {
        let addr = Signer::address_of(issuer_acc);
        assert(exists<Collection<Type>>(addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(addr);
        let token_id = collection.token_counter;
        collection.token_counter = token_id + 1;

        let pubkey_id = *&collection.pubkey_id;
        let token = NFT<Type> { collection_id: copy pubkey_id, id: token_id, content };
        move_to(issuer_acc, token);
    }

    #[test_only]
    public fun get_number_of_tokens_minted<Type: store>(issuer_acc: &signer): u64 acquires Collection {
        let addr = Signer::address_of(issuer_acc);
        assert(exists<Collection<Type>>(addr), ERR_COLLECTION_DOES_NOT_EXIST);

        let collection = borrow_global_mut<Collection<Type>>(addr);
        collection.token_counter
    }
}



















