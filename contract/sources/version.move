module cyberfrog::version;

use std::type_name::{Self, TypeName};
use sui::{
    vec_set::{Self, VecSet},
};
// ====== Constants =======
const VERSION: u64 = 1;

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

public fun create_validator_cap(_: &SuperAdminCap): ValidatorCap {
    ValidatorCap {}
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