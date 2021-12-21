#[test_only]
module Sender::RMRKTests {
    use Sender::RMRK;
    use Std::DiemBlock;
    use Std::ASCII::string;

    struct KittenImage has store, drop {}

    fun create_kittens_collection(acc: &signer, max_items: u64) {
        let collection_id = string(b"11112222-KITTEN_COLL");
        let collection_uri = string(b"http://kittens.com");
        RMRK::create_collection<KittenImage>(
            acc, collection_id, collection_uri, max_items);
    }

    #[test(acc = @0x42)]
    #[expected_failure(abort_code = 24)]
    fun test_cannot_create_more_token_than_max_items_of_tokens(acc: signer) {
        create_kittens_collection(&acc, 1);

        RMRK::create_nft_storage<KittenImage>(&acc);

        RMRK::mint_token(
            &acc, KittenImage{}, 0, @0x42);
        RMRK::mint_token(
            &acc, KittenImage{}, 0, @0x42);
    }

    #[test(acc = @0x42)]
    #[expected_failure(abort_code = 25)]
    fun test_cannot_create_tokens_for_a_locked_collection(acc: signer) {
        create_kittens_collection(&acc, 0);

        RMRK::create_nft_storage<KittenImage>(&acc);
        RMRK::mint_token(
            &acc, KittenImage{}, 0, @0x42);

        RMRK::lock_collection<KittenImage>(&acc);

        RMRK::mint_token(
            &acc, KittenImage{}, 0, @0x42);
    }

    #[test(acc = @0x42, owner_acc = @0x2)]
    fun test_create_nft_storage_and_mint_token_there(acc: signer, owner_acc: signer) {
        create_kittens_collection(&acc, 0);
        assert(RMRK::get_number_of_tokens_minted<KittenImage>(&acc) == 0, 1);

        RMRK::create_nft_storage<KittenImage>(&owner_acc);

        let kitten = KittenImage{};
        RMRK::mint_token(&acc, kitten, 0, @0x2);
        assert(RMRK::get_number_of_tokens_minted<KittenImage>(&acc) == 1, 2);
        assert(RMRK::token_exists<KittenImage>(@0x2), 2);
    }

    #[test(acc = @0x42)]
    #[expected_failure(abort_code = 1)]
    fun test_aborts_if_two_collections_with_the_same_type_are_created(acc: signer) {
        create_kittens_collection(&acc, 0);

        let collection_id = string(b"11113333-KITTEN_COLL");
        let collection_uri = string(b"http://kittens.com");
        RMRK::create_collection<KittenImage>(
            &acc, collection_id, collection_uri, 0);
    }

    #[test(acc = @0x42, new_issuer_acc = @0x43)]
    fun test_change_issuer_of_the_collection(acc: signer, new_issuer_acc: signer) {
        create_kittens_collection(&acc, 0);

        let new_issuer_addr = @0x43;
        assert(RMRK::collection_exists<KittenImage>(@0x42), 1);
        assert(!RMRK::collection_exists<KittenImage>(new_issuer_addr), 1);

        RMRK::change_collection_issuer<KittenImage>(&acc, new_issuer_addr);
        RMRK::accept_collection_as_new_issuer<KittenImage>(&new_issuer_acc, @0x42);

        assert(!RMRK::collection_exists<KittenImage>(@0x42), 1);
        assert(RMRK::collection_exists<KittenImage>(new_issuer_addr), 1);
    }

    #[test(acc = @0x42, new_issuer_acc = @0x43)]
    #[expected_failure(abort_code = 5)]
    fun test_cannot_accept_collection_if_issuer_change_cancelled(acc: signer, new_issuer_acc: signer) {
        let new_issuer_addr = @0x43;
        create_kittens_collection(&acc, 0);

        RMRK::change_collection_issuer<KittenImage>(&acc, new_issuer_addr);
        RMRK::cancel_collection_issuer_change<KittenImage>(&acc);

        RMRK::accept_collection_as_new_issuer<KittenImage>(&new_issuer_acc, @0x42);
    }

    #[test(acc = @0x42, new_issuer_acc = @0x43)]
    #[expected_failure(abort_code = 5)]
    fun test_cannot_accept_collection_if_not_changed(acc: signer, new_issuer_acc: signer) {
        create_kittens_collection(&acc, 0);

        RMRK::accept_collection_as_new_issuer<KittenImage>(&new_issuer_acc, @0x42);
    }

    #[test(issuer_acc = @0x42, owner_acc = @0x2)]
    fun test_burn_token(issuer_acc: signer, owner_acc: signer) {
        create_kittens_collection(&issuer_acc, 0);

        let owner_addr = @0x2;
        RMRK::create_nft_storage<KittenImage>(&owner_acc);
        RMRK::mint_token(&issuer_acc, KittenImage{}, 0, owner_addr);
        assert(RMRK::token_exists<KittenImage>(owner_addr), 1);

        RMRK::burn_token<KittenImage>(&owner_acc, 1, @0x42);
        assert(!RMRK::token_exists<KittenImage>(owner_addr), 1);
        assert(RMRK::get_number_of_tokens_minted<KittenImage>(&issuer_acc) == 0, 2);
    }

    #[test(issuer_acc = @0x42, owner1_acc = @0x2, owner2_acc = @0x3)]
    #[expected_failure(abort_code = 45)]
    fun test_cannot_send_token_if_not_transferrable(issuer_acc: signer, owner1_acc: signer, owner2_acc: signer) {
        create_kittens_collection(&issuer_acc, 0);

        RMRK::create_nft_storage<KittenImage>(&owner1_acc);
        let token_id = RMRK::mint_token(
            &issuer_acc, KittenImage{}, 0, @0x2);
        assert(RMRK::token_exists<KittenImage>(@0x2), 1);

        RMRK::create_nft_storage<KittenImage>(&owner2_acc);
        RMRK::send_token_to_account<KittenImage>(&owner1_acc, token_id, @0x3);
    }

    #[test(dr_acc = @DiemRoot, issuer_acc = @0x42, owner1_acc = @0x2, owner2_acc = @0x3)]
    #[expected_failure(abort_code = 45)]
    fun test_token_is_not_transferrable_if_number_of_blocks_not_reached(dr_acc: signer, issuer_acc: signer, owner1_acc: signer, owner2_acc: signer) {
        create_kittens_collection(&issuer_acc, 0);

        RMRK::create_nft_storage<KittenImage>(&owner1_acc);
        let token_id = RMRK::mint_token(
            &issuer_acc, KittenImage{}, 10, @0x2);
        DiemBlock::set_current_block_height(&dr_acc, 1);

        RMRK::create_nft_storage<KittenImage>(&owner2_acc);
        RMRK::send_token_to_account<KittenImage>(&owner1_acc, token_id, @0x3);
    }

    #[test(dr_acc = @DiemRoot, issuer_acc = @0x42, owner1_acc = @0x2, owner2_acc = @0x3)]
    fun test_token_transferable_after_block_height(dr_acc: signer, issuer_acc: signer, owner1_acc: signer, owner2_acc: signer) {
        create_kittens_collection(&issuer_acc, 0);

        RMRK::create_nft_storage<KittenImage>(&owner1_acc);
        let token_id = RMRK::mint_token(
            &issuer_acc, KittenImage{}, 10, @0x2);
        DiemBlock::set_current_block_height(&dr_acc, 20);

        RMRK::create_nft_storage<KittenImage>(&owner2_acc);
        RMRK::send_token_to_account<KittenImage>(&owner1_acc, token_id, @0x3);
        assert(!RMRK::token_exists<KittenImage>(@0x2), 2);
        assert(RMRK::token_exists<KittenImage>(@0x3), 3);
    }
}















