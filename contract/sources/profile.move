module cyberfrog::profile;

use std::{
    string::{Self, String},
    type_name::TypeName,
};

use sui::{
    event::emit,
    table::{Self, Table},
};

use cyberfrog::version::{SuperAdminCap, check_validator, Validators};

// Events
public struct ProfileCreated has copy, drop {
    profile_id: ID,
    name: String,
    bouding_addr: Option<address>,
}

public struct ProfileUpdated has copy, drop {
    profile_id: ID,
    field: String,
}

const ERROR_PROFILE_EXISTS: u64 = 1;
const ERROR_JOURNEY_EXISTS: u64 = 2;
const ERROR_TOKEN_NOT_FOUND: u64 = 3;
const ERROR_CARD_NOT_FOUND: u64 = 4;
const ERROR_INVALID_VALIDATOR: u64 = 5;
const ERROR_BOUDING_ADDR_NOT_FOUND: u64 = 6;

public struct State has key {
    id: UID,
    profiles: Table<ID, bool>,
}

public struct Profile has key {
    id: UID,
    name: String,
    bouding_addr: Option<address>,
    journey_records: Table<String, bool>,
    tokens: Table<TypeName, u64>,
    cards: Table<TypeName, u8>,
}

fun init(ctx: &mut TxContext) {
    let state = State {
        id: object::new(ctx),
        profiles: table::new(ctx),
    };
    transfer::share_object(state);
}

public fun create_profile<T: drop>(
    ctx: &mut TxContext,
    name: String,
    bouding_addr: Option<address>,
    validators: &Validators,
    state: &mut State
): Profile {

    assert!(check_validator<T>(validators), ERROR_INVALID_VALIDATOR);

    let profile = Profile {
        id: object::new(ctx),
        name,
        bouding_addr,
        journey_records: table::new(ctx),
        tokens: table::new(ctx),
        cards: table::new(ctx),
    };
    
    let profile_id = profile.id.to_inner();
    assert!(!table::contains(&state.profiles, profile_id), ERROR_PROFILE_EXISTS);
    
    table::add(&mut state.profiles, profile_id, true);
    
    emit(ProfileCreated {
        profile_id,
        name,
        bouding_addr,
    });

    profile
}

public fun add_journey<T: drop>(
    profile: &mut Profile,
    journey: String,
    is_finish: bool,
    validators: &Validators
) {
    assert!(check_validator<T>(validators), ERROR_INVALID_VALIDATOR);

    assert!(!table::contains(&profile.journey_records, journey), ERROR_JOURNEY_EXISTS);
    
    table::add(&mut profile.journey_records, journey, is_finish);
    let profile_id = profile.id.to_inner();
    emit(ProfileUpdated { profile_id, field: string::utf8(b"journey") });
}

public fun add_token<T: drop>(
    profile: &mut Profile,
    token: TypeName,
    amount: u64,
    validators: &Validators
) {
    assert!(check_validator<T>(validators), ERROR_INVALID_VALIDATOR);

    assert!(!table::contains(&profile.tokens, token), ERROR_TOKEN_NOT_FOUND);
    
    table::add(&mut profile.tokens, token, amount);
    let profile_id = profile.id.to_inner();
    emit(ProfileUpdated { profile_id, field: string::utf8(b"token") });
}

public fun add_card<T: drop>(
    profile: &mut Profile,
    card: TypeName,
    amount: u8,
    validators: &Validators
) {
    assert!(check_validator<T>(validators), ERROR_INVALID_VALIDATOR);

    assert!(!table::contains(&profile.cards, card), ERROR_CARD_NOT_FOUND);
    
    table::add(&mut profile.cards, card, amount);
    
    let profile_id = profile.id.to_inner(); 
    emit(ProfileUpdated { profile_id, field: string::utf8(b"card") });
}

public fun edit_journey<T: drop>(
    _admin: &SuperAdminCap,
    profile: &mut Profile,
    journey: String,
    is_finish: bool,
    validators: &Validators
) {
    assert!(check_validator<T>(validators), ERROR_INVALID_VALIDATOR);

    assert!(table::contains(&profile.journey_records, journey), ERROR_JOURNEY_EXISTS);
    
    let journey_data = table::borrow_mut(&mut profile.journey_records, journey);
    *journey_data = is_finish;
    
    let profile_id = profile.id.to_inner();
    emit(ProfileUpdated { profile_id, field: string::utf8(b"journey") });
}

public fun edit_token<T: drop>(
    profile: &mut Profile,
    token: TypeName,
    amount: u64,
    validators: &Validators
) {
    assert!(check_validator<T>(validators), ERROR_INVALID_VALIDATOR);

    assert!(table::contains(&profile.tokens, token), ERROR_TOKEN_NOT_FOUND);
    
    let token_data = table::borrow_mut(&mut profile.tokens, token);
    *token_data = amount;
    
    let profile_id = profile.id.to_inner();
    emit(ProfileUpdated { profile_id, field: string::utf8(b"token") });
}

public fun edit_card<T: drop>(
    profile: &mut Profile,
    card: TypeName,
    amount: u8,
    validators: &Validators
) {
    assert!(check_validator<T>(validators), ERROR_INVALID_VALIDATOR);

    assert!(table::contains(&profile.cards, card), ERROR_CARD_NOT_FOUND);
    
    let card_data = table::borrow_mut(&mut profile.cards, card);
    *card_data = amount;
    
    let profile_id = profile.id.to_inner();
    emit(ProfileUpdated { profile_id, field: string::utf8(b"card") });
}

// Getter

public fun get_profile_token(
    profile: &Profile,
    token: TypeName,
): u64 {
   let token_data = table::borrow(&profile.tokens, token);
   *token_data
}

public fun get_profile_bouding_addr(
    profile: &Profile,
): address {
    assert!(profile.bouding_addr.is_some(), ERROR_BOUDING_ADDR_NOT_FOUND);
    let bouding_addr = profile.bouding_addr.borrow();
    *bouding_addr
}


