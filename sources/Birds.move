module Sender::Birds {
    use Sender::RMRK;
    use Std::ASCII;

    struct Bird has store, drop {
        uri: ASCII::String,
    }

    public fun create_birds_collection(issuer_acc: &signer) {
        // TODO: get issuer pubkey_id
        let collection_id = ASCII::string(b"birds_collection_id");
        let collection_uri = ASCII::string(b"http://birds_collection.com");
        RMRK::create_collection<Bird>(issuer_acc, collection_id, collection_uri, 10);
    }

    public fun create_birds_nft_storage(owner_acc: &signer) {
        RMRK::create_nft_storage<Bird>(owner_acc);
    }

    public fun mint_bird_nft(issuer_acc: &signer, bird_uri: ASCII::String, owner_addr: address): u64 {
        let bird = Bird { uri: bird_uri };
        RMRK::mint_token(issuer_acc, bird, 1, owner_addr)
    }
}
