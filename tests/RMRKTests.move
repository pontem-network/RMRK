#[test_only]
module Sender::RMRKTests {
    use Sender::RMRK;

    struct KittenImage has store {}

    #[test(acc = @0x42)]
    fun test_create_collection_and_mint_token(acc: signer) {
        RMRK::create_collection<KittenImage>(&acc, b"11112222-KITTEN_COLL");
        assert(RMRK::get_number_of_tokens_minted<KittenImage>(&acc) == 0, 1);

        let kitten = KittenImage {};
        RMRK::mint_token(&acc, kitten);
        assert(RMRK::get_number_of_tokens_minted<KittenImage>(&acc) == 1, 2);
    }

    #[test(acc = @0x42)]
    #[expected_failure(abort_code = 1)]
    fun test_aborts_if_two_collections_with_the_same_type_are_created(acc: signer) {
        RMRK::create_collection<KittenImage>(&acc, b"11112222-KITTEN_COLL");
        RMRK::create_collection<KittenImage>(&acc, b"11113333-KITTEN_COLL");
    }

//    #[test(acc = @0x42)]
//    fun test_change_issuer_of_the_collection(acc: signer) {
//        RMRK::create_collection<KittenImage>(&acc, b"11112222-KITTEN_COLL");
//
//    }
}