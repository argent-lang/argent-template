use argent::build_file;
use argent_runtime::{EntryCall, TxBuilder, TxContext, args as entry_args, state as actor_state};
use argent_template::{DemoResult, demo_keys, demo_outpoint, print_tx_summary};
use kaspa_consensus_core::{Hash, tx::CovenantBinding};

fn main() -> DemoResult<()> {
    let artifact = build_file("ag/event.ag", "build/event")?;
    let builder = TxBuilder::new(&artifact)?;

    /*
       event state before
       event state after
       ticket state after

       state EventState {
           int remaining_tickets;
           int serial;
           int price;
       }

       state TicketState {
           pubkey owner;
           int serial;
       }
    */

    let (_buyer, buyer_pk) = demo_keys(23);

    let cov_id = Hash::from_u64_word(257);
    let event_before = actor_state! { remaining_tickets: 7, serial: 56, price: 1000 };
    let event_after = actor_state! { remaining_tickets: 6, serial: 57, price: 1000 };
    let new_ticket = actor_state! { owner: buyer_pk.clone(), serial: 56 };
    let buy_args = entry_args![buyer_pk.clone()];

    // get the utxo of the event from a kaspa node or from storage
    let outpoint = demo_outpoint(67, 0);
    let utxo = builder.covenant_utxo("Event", event_before.clone(), 500, 0, false, Some(cov_id))?;

    let ctx = TxContext::new()
        .actor_input("Event", event_before, EntryCall::new("buy").args(buy_args), outpoint, utxo, 0)
        .actor_output("Event", event_after, CovenantBinding::new(0, cov_id), 1500)
        .actor_output("Ticket", new_ticket, CovenantBinding::new(0, cov_id), 1);

    let tx = builder.build(&ctx)?;

    print_tx_summary(&tx);

    Ok(())
}
