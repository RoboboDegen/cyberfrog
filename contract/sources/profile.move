module cyberfrog::profile;

use cyberfrog::version::{off_chain_validation, create_off_chain_validator, OffChainValidator};
use std::string::{Self, String};
use std::type_name::TypeName;
use sui::clock::Clock;
use sui::event::emit;
use sui::table::{Self, Table};

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
const ERROR_PROFILE_NOT_FOUND: u64 = 7;

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
    cards: Table<String, u64>,
    last_time: u64,
}

fun init(ctx: &mut TxContext) {
    let state = State {
        id: object::new(ctx),
        profiles: table::new(ctx),
    };
    transfer::share_object(state);
}

public fun create_profile(
    ctx: &mut TxContext,
    name: String,
    bouding_addr: Option<address>,
    sig: vector<u8>,
    time: u64,
    state: &mut State,
): Profile {
    let off_chain_validator = create_off_chain_validator(time, ctx);

    assert!(
        off_chain_validation<OffChainValidator>(sig, off_chain_validator),
        ERROR_INVALID_VALIDATOR,
    );

    let profile = Profile {
        id: object::new(ctx),
        name,
        bouding_addr,
        journey_records: table::new(ctx),
        tokens: table::new(ctx),
        cards: table::new(ctx),
        last_time: time,
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

public fun add_journey(
    profile: &mut Profile,
    journey: String,
    is_finish: bool,
    sig: vector<u8>,
    state: &mut State,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let last_time = clock.timestamp_ms();
    let off_chain_validator = create_off_chain_validator(last_time, ctx);
    assert!(
        off_chain_validation<OffChainValidator>(sig, off_chain_validator),
        ERROR_INVALID_VALIDATOR,
    );
    assert!(check_profile_exists(profile, state), ERROR_PROFILE_NOT_FOUND);
    assert!(!table::contains(&profile.journey_records, journey), ERROR_JOURNEY_EXISTS);

    table::add(&mut profile.journey_records, journey, is_finish);
    profile.last_time = last_time;
    let profile_id = profile.id.to_inner();
    emit(ProfileUpdated { profile_id, field: string::utf8(b"journey") });
}

public fun add_token(
    profile: &mut Profile,
    token: TypeName,
    amount: u64,
    sig: vector<u8>,
    state: &mut State,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let last_time = clock.timestamp_ms();
    let off_chain_validator = create_off_chain_validator(last_time, ctx);
    assert!(
        off_chain_validation<OffChainValidator>(sig, off_chain_validator),
        ERROR_INVALID_VALIDATOR,
    );
    assert!(check_profile_exists(profile, state), ERROR_PROFILE_NOT_FOUND);
    assert!(!table::contains(&profile.tokens, token), ERROR_TOKEN_NOT_FOUND);

    table::add(&mut profile.tokens, token, amount);
    let profile_id = profile.id.to_inner();
    emit(ProfileUpdated { profile_id, field: string::utf8(b"token") });
}

public fun add_card(
    profile: &mut Profile,
    card: String,
    expire_time: u64,
    sig: vector<u8>,
    state: &mut State,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let last_time = clock.timestamp_ms();
    let off_chain_validator = create_off_chain_validator(last_time, ctx);
    assert!(
        off_chain_validation<OffChainValidator>(sig, off_chain_validator),
        ERROR_INVALID_VALIDATOR,
    );
    assert!(check_profile_exists(profile, state), ERROR_PROFILE_NOT_FOUND);
    assert!(!table::contains(&profile.cards, card), ERROR_CARD_NOT_FOUND);

    table::add(&mut profile.cards, card, expire_time);
    profile.last_time = last_time;
    let profile_id = profile.id.to_inner();
    emit(ProfileUpdated { profile_id, field: string::utf8(b"card") });
}

public fun edit_journey(
    profile: &mut Profile,
    journey: String,
    is_finish: bool,
    sig: vector<u8>,
    state: &mut State,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let last_time = clock.timestamp_ms();
    let off_chain_validator = create_off_chain_validator(last_time, ctx);
    assert!(
        off_chain_validation<OffChainValidator>(sig, off_chain_validator),
        ERROR_INVALID_VALIDATOR,
    );
    assert!(check_profile_exists(profile, state), ERROR_PROFILE_NOT_FOUND);
    assert!(table::contains(&profile.journey_records, journey), ERROR_JOURNEY_EXISTS);

    let journey_data = table::borrow_mut(&mut profile.journey_records, journey);
    *journey_data = is_finish;
    profile.last_time = last_time;
    let profile_id = profile.id.to_inner();
    emit(ProfileUpdated { profile_id, field: string::utf8(b"journey") });
}

public fun edit_token(
    profile: &mut Profile,
    token: TypeName,
    amount: u64,
    sig: vector<u8>,
    state: &mut State,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let last_time = clock.timestamp_ms();
    let off_chain_validator = create_off_chain_validator(last_time, ctx);
    assert!(
        off_chain_validation<OffChainValidator>(sig, off_chain_validator),
        ERROR_INVALID_VALIDATOR,
    );
    assert!(check_profile_exists(profile, state), ERROR_PROFILE_NOT_FOUND);
    assert!(table::contains(&profile.tokens, token), ERROR_TOKEN_NOT_FOUND);

    let token_data = table::borrow_mut(&mut profile.tokens, token);
    *token_data = amount;
    profile.last_time = last_time;
    let profile_id = profile.id.to_inner();
    emit(ProfileUpdated { profile_id, field: string::utf8(b"token") });
}

public fun edit_card(
    profile: &mut Profile,
    card: String,
    expire_time: u64,
    sig: vector<u8>,
    state: &mut State,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let last_time = clock.timestamp_ms();
    let off_chain_validator = create_off_chain_validator(last_time, ctx);
    assert!(
        off_chain_validation<OffChainValidator>(sig, off_chain_validator),
        ERROR_INVALID_VALIDATOR,
    );
    assert!(check_profile_exists(profile, state), ERROR_PROFILE_NOT_FOUND);
    assert!(table::contains(&profile.cards, card), ERROR_CARD_NOT_FOUND);

    let card_expire_time = table::borrow_mut(&mut profile.cards, card);
    *card_expire_time = expire_time;
    profile.last_time = last_time;
    let profile_id = profile.id.to_inner();
    emit(ProfileUpdated { profile_id, field: string::utf8(b"card") });
}

// Getter

public fun get_profile_token(profile: &Profile, token: TypeName): u64 {
    let token_data = table::borrow(&profile.tokens, token);
    *token_data
}

public fun has_card(profile: &Profile, card: String): bool {
    table::contains(&profile.cards, card)
}

public fun get_profile_bouding_addr(profile: &Profile): address {
    assert!(profile.bouding_addr.is_some(), ERROR_BOUDING_ADDR_NOT_FOUND);
    let bouding_addr = profile.bouding_addr.borrow();
    *bouding_addr
}

public fun check_profile_exists(profile: &Profile, state: &State): bool {
    table::contains(&state.profiles, profile.id.to_inner())
}
