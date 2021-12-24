module Sender::Billboards {
    use Std::ASCII::String;
    use Sender::RMRK;

    /// Only account with existing NFT<Land> with that land_url can issue new Ownership claims with that url.
    /// Only account with existing NFT<Land> can withdraw Ownership claim from specific account.
    struct Ownership has store, drop {
        land_url: String,
    }

    struct Land has store, drop {
        symbol: String,
        land_coordinates_url: String,
    }

    public fun mint_land_nft(issuer_acc: &signer, symbol: String, land_url: String): RMRK::NFT<Land> {
        let land = Land { land_coordinates_url: land_url, symbol };
        let nft = RMRK::mint_nft(issuer_acc, land, 1);
        nft
    }
}
