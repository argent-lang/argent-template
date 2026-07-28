use argent::build_file;
use argent_runtime::{EntryCall, TxBuilder, TxContext, args, state, stdlib::core::invocation_uid};
use argent_template::{DemoResult, demo_outpoint, print_tx_summary};
use blake2b_simd::Params as Blake2bParams;
use kaspa_consensus_core::{
    Hash,
    tx::{CovenantBinding, TransactionOutpoint},
};

fn main() -> DemoResult<()> {
    let artifact = build_file("ag/counter.ag", "build/counter")?;
    let builder = TxBuilder::new(&artifact)?;

    // prep data
    let count = 2i64;
    let delta = 3i64;
    let counter_outpoint = demo_outpoint(0x11, 0);
    let previous_receipt = Hash::from_bytes([0u8; 32]);
    let receipt = bump_receipt(&counter_outpoint, count, delta, previous_receipt)?;

    // build state objects
    let before = state! {
        count: count,
        receipt: previous_receipt,
    };
    let after = state! {
        count: count + delta,
        receipt: receipt,
    };
    let value = 1_000;
    let covenant_id = Hash::from_bytes([0x42; 32]);

    let counter_utxo = builder.covenant_utxo("Counter", before.clone(), value, 0, false, Some(covenant_id))?;
    let context = TxContext::new()
        .actor_input("Counter", before, EntryCall::new("bump").args(args![delta]), counter_outpoint, counter_utxo, 0)
        .actor_output("Counter", after, CovenantBinding::new(0, covenant_id), value);

    let tx = builder.build(&context)?;

    println!("built Counter::bump");
    print_tx_summary(&tx);
    println!("artifact: build/counter/artifact.json");
    Ok(())
}

fn bump_receipt(outpoint: &TransactionOutpoint, count: i64, delta: i64, previous_receipt: Hash) -> DemoResult<Hash> {
    let invocation = invocation_uid(outpoint, b"Counter.bump.receipt")?;
    let receipt = Blake2bParams::new()
        .hash_length(32)
        .to_state()
        .update(&previous_receipt.as_bytes())
        .update(&invocation.as_bytes())
        .update(&count.to_le_bytes())
        .update(&delta.to_le_bytes())
        .finalize();
    Ok(Hash::from_slice(receipt.as_bytes()))
}
