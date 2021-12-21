module Sender::BirdsTests {
    use Sender::Birds;
    use Std::ASCII::string;

    #[test(issuer_acc = @0x2, owner_acc = @0x42)]
    fun test_mint_bird_nft(issuer_acc: signer, owner_acc: signer) {
        Birds::create_birds_collection(&issuer_acc);

        Birds::create_birds_wallet(&owner_acc);
        Birds::mint_bird_nft(&issuer_acc, string(b"http://birds.com/1"), @0x42);
    }
}
