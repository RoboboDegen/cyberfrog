module cyberfrog::version;

use std::type_name::{Self, TypeName};
use sui::{
    vec_set::{Self, VecSet},
    ed25519,
    hash,
    bcs
};
// ====== Constants =======
const VERSION: u64 = 1;

const PK: vector<u8> = vector[185, 198, 238, 22, 48, 
    239, 62, 113, 17, 68, 166, 72, 219, 6, 187, 178, 
    40, 79, 114, 116, 207, 190, 229, 63, 252, 238, 80, 
    60, 193, 164, 146, 0];

public struct Version has key {
    id: UID,
    version: u64,
}

public struct SuperAdminCap has key {
    id: UID,
}

public struct Validators has key {
    id: UID,
    validators: VecSet<TypeName>,
}

public struct ValidatorCap has drop {}

public struct OffChainValidator has drop {
    addr:address,
    last_time:u64
}

fun init(ctx: &mut TxContext) {
    let version = Version {
        id: object::new(ctx),
        version: VERSION,
    };
    transfer::share_object(version);

    let mut validators = Validators {
        id: object::new(ctx),
        validators: vec_set::empty(),
    };

    let validator_cap_type = type_name::get<ValidatorCap>();
    vec_set::insert(&mut validators.validators, validator_cap_type);
    
    transfer::share_object(validators);
}

public fun off_chain_validation<T:drop>(sig:vector<u8>,value:T): bool {
    let pk = PK;
    let byte_data = bcs::to_bytes(&value);
    let hash_data = hash::keccak256(&byte_data);
    ed25519::ed25519_verify(&sig, &pk, &hash_data)
}

public(package) fun create_off_chain_validator(time:u64,ctx:&TxContext): OffChainValidator {
    OffChainValidator {
        addr:ctx.sender(),
        last_time: time
    }
}

public fun add_validator<T: drop>(_: &SuperAdminCap, validators: &mut Validators) {
    let validator_cap_type = type_name::get<T>();
    vec_set::insert(&mut validators.validators, validator_cap_type);
}

public fun remove_validator<T: drop>(_: &SuperAdminCap, validators: &mut Validators) {
    let validator_cap_type = type_name::get<T>();
    vec_set::remove(&mut validators.validators, &validator_cap_type);
}

public fun check_validator<T: drop>(validators: &Validators): bool {
    let validator_cap_type = type_name::get<T>();
    vec_set::contains(&validators.validators, &validator_cap_type)
}

public fun check_version(version: &Version) {
    assert!(version.version == VERSION);
}

public fun update_version(_admin: &SuperAdminCap, version: &mut Version) {
    assert!(version.version < VERSION);
    version.version = VERSION;
}