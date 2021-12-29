module Sender::Birds {
    use Sender::RMRK::{Self, NFT};
    use Std::ASCII::{Self, String};
    use Std::Option::{Self, Option};

    struct BirdImage has store, drop {
        content_url: String,
        head: Option<NFT<BirdImageItem>>,
        background: Option<NFT<BirdImageItem>>,
    }

    struct BirdImageItem has store, drop {
        content_url: String,
    }

    public fun create_birds_collection(issuer_acc: &signer) {
        RMRK::initialize_issuer<BirdImage>(issuer_acc);
        // TODO: get issuer pubkey_id
        let collection_id = ASCII::string(b"birds_collection_id");
        let collection_uri = ASCII::string(b"http://birds_collection.com");
        RMRK::create_collection<BirdImage>(issuer_acc, collection_id, collection_uri, 10);
    }

    public fun create_bird_items_collection(issuer_acc: &signer) {
        // TODO: get issuer pubkey_id
        let collection_id = ASCII::string(b"bird_items_collection_id");
        let collection_uri = ASCII::string(b"http://bird_items_collection.com");
        RMRK::create_collection<BirdImageItem>(issuer_acc, collection_id, collection_uri, 10);
    }

    public fun create_bird_wallets(owner_acc: &signer) {
        RMRK::create_nft_wallet<BirdImage>(owner_acc);
        RMRK::create_nft_wallet<BirdImageItem>(owner_acc);
    }

    public fun mint_bird_nft(issuer_acc: &signer, bird_url: String, owner_addr: address) {
        let bird = BirdImage{ content_url: bird_url, head: Option::none(), background: Option::none() };
        let nft = RMRK::mint_nft(issuer_acc, bird, 1);
        RMRK::add_nft_to_wallet(nft, owner_addr);
    }
}
