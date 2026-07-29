use kaspa_consensus_core::{
    hashing::{
        sighash::{SigHashReusedValuesUnsync, calc_schnorr_signature_hash},
        sighash_type::SIG_HASH_ALL,
    },
    tx::{MutableTransaction, ScriptPublicKey, Transaction, TransactionId, TransactionOutpoint, UtxoEntry},
};
use secp256k1::{Keypair, Secp256k1, SecretKey};

pub type DemoResult<T> = Result<T, Box<dyn std::error::Error>>;

/// Returns a deterministic outpoint for local examples.
pub fn demo_outpoint(byte: u8, index: u32) -> TransactionOutpoint {
    TransactionOutpoint { transaction_id: TransactionId::from_bytes([byte; 32]), index }
}

/// Returns a deterministic keypair for local examples.
pub fn demo_keypair(byte: u8) -> Keypair {
    let secret_key = SecretKey::from_slice(&[byte; 32]).expect("demo secret key is valid");
    Keypair::from_secret_key(&Secp256k1::new(), &secret_key)
}

/// Returns a deterministic keypair and its 32-byte x-only public key.
pub fn demo_keys(byte: u8) -> (Keypair, Vec<u8>) {
    let keypair = demo_keypair(byte);
    let public_key = keypair.x_only_public_key().0.serialize().to_vec();
    (keypair, public_key)
}

/// Returns a simple local funding UTXO.
pub fn demo_funding_utxo(value: u64) -> UtxoEntry {
    UtxoEntry::new(value, ScriptPublicKey::from_vec(0, vec![0x51]), 0, false, None)
}

/// Signs one transaction input with `SIGHASH_ALL`.
pub fn sign_input<T: AsRef<Transaction>>(tx: &MutableTransaction<T>, input_idx: usize, keypair: &Keypair) -> Vec<u8> {
    let reused_values = SigHashReusedValuesUnsync::new();
    let sig_hash = calc_schnorr_signature_hash(&tx.as_verifiable(), input_idx, SIG_HASH_ALL, &reused_values);
    let message = secp256k1::Message::from_digest(sig_hash.as_bytes());
    let signature = keypair.sign_schnorr(message);
    let mut encoded = signature.as_ref().to_vec();
    encoded.push(SIG_HASH_ALL.to_u8());
    encoded
}

/// Prints a compact summary suitable for a live demo.
pub fn print_tx_summary(tx: &Transaction) {
    println!("transaction: {}", tx.id());
    println!("inputs: {}", tx.inputs.len());
    println!("outputs: {}", tx.outputs.len());
}
