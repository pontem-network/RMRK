/// This module defines a struct storing the metadata of the block and new block events.
module Std::DiemBlock {
    struct BlockMetadata has key {
        /// Height of the current block
        height: u64,
    }

    struct NewBlockEvent has drop, store {
        round: u64,
        proposer: address,
        previous_block_votes: vector<address>,

        /// On-chain time during  he block at the given height
        time_microseconds: u64,
    }

    /// Helper function to determine whether this module has been initialized.
    fun is_initialized(): bool {
        exists<BlockMetadata>(@DiemRoot)
    }


    /// Get the current block height
    public fun get_current_block_height(): u64 acquires BlockMetadata {
        borrow_global<BlockMetadata>(@DiemRoot).height
    }

    #[test_only]
    public fun set_current_block_height(diem_root_acc: &signer, height: u64) acquires BlockMetadata {
        if (!is_initialized()) {
            move_to<BlockMetadata>(diem_root_acc, BlockMetadata {height: 0});
        };
        borrow_global_mut<BlockMetadata>(@DiemRoot).height = height;
    }
}
