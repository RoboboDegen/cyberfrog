module cyberfrog::game;

use cyberfrog::profile::{Self, Profile, State as ProfileState};
use cyberfrog::version::{
    SuperAdminCap,
    off_chain_validation,
    create_off_chain_validator,
    OffChainValidator
};
use std::string::String;
use std::type_name::{Self, TypeName};
use sui::clock::Clock;
use sui::event::emit;
use sui::table::{Self, Table};

// == 错误常量 ==
const ERROR_JOURNEY_EXISTS: u64 = 1;
const ERROR_JOURNEY_NOT_FOUND: u64 = 2;
const ERROR_INVALID_VALIDATOR: u64 = 3;
const ERROR_PROFILE_MISMATCH: u64 = 4;

// == 事件 ==
public struct JourneyRecorded has copy, drop {
    journey_id: ID,
    player: address,
    success: bool,
    rewards: u64,
}

public struct JourneyMinted has copy, drop {
    journey_id: ID,
    player: address,
}

public struct GameState has key {
    id: UID,
    journey_records: Table<ID, JourneyData>,
    minted_journeys: Table<ID, bool>,
}

public struct JourneyData has copy, store {
    name: String,
    player: address,
    success: bool,
    rewards: u64,
    description: String,
}

public struct JourneyNFT has key {
    id: UID,
    data: JourneyData,
}

fun init(ctx: &mut TxContext) {
    let game_state = GameState {
        id: object::new(ctx),
        journey_records: table::new(ctx),
        minted_journeys: table::new(ctx),
    };

    transfer::share_object(game_state);
}

public fun record_journey(
    player_address: address,
    _: &SuperAdminCap,
    name: String,
    success: bool,
    rewards: u64,
    description: String,
    sig: vector<u8>,
    profile: &mut Profile,
    clock: &Clock,
    profile_state: &mut ProfileState,
    game_state: &mut GameState,
    ctx: &mut TxContext,
) {
    assert!(profile::check_profile_exists(profile, profile_state), ERROR_PROFILE_MISMATCH);

    let temp_uid = object::new(ctx);
    let journey_id = object::uid_to_inner(&temp_uid);
    object::delete(temp_uid);

    let journey_data = JourneyData {
        name,
        player: player_address,
        success,
        rewards,
        description,
    };

    table::add(&mut game_state.journey_records, journey_id, journey_data);

    profile::add_journey(
        profile,
        name,
        success,
        sig,
        profile_state,
        clock,
        ctx,
    );

    if (success && rewards > 0) {
        profile::add_token(
            profile,
            std::type_name::get<TypeName>(),
            rewards,
            sig,
            profile_state,
            clock,
            ctx,
        );
    };

    emit(JourneyRecorded {
        journey_id,
        player: player_address,
        success,
        rewards,
    });
}

public fun mint_journey_nft(
    journey_id: ID,
    sig: vector<u8>,
    profile: &mut Profile,
    profile_state: &mut ProfileState,
    game_state: &mut GameState,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let current_time = clock.timestamp_ms();
    let off_chain_validator = create_off_chain_validator(current_time, ctx);
    assert!(
        off_chain_validation<OffChainValidator>(sig, off_chain_validator),
        ERROR_INVALID_VALIDATOR,
    );

    // 验证Profile存在
    assert!(profile::check_profile_exists(profile, profile_state), ERROR_PROFILE_MISMATCH);
    assert!(!table::contains(&game_state.minted_journeys, journey_id), ERROR_JOURNEY_EXISTS);
    //todo 需要一个确定profile中是否含有该journey的函数

    // 获取旅程数据
    let journey_data = table::borrow(&game_state.journey_records, journey_id);

    let journey_nft = JourneyNFT {
        id: object::new(ctx),
        data: *journey_data,
    };

    table::add(&mut game_state.minted_journeys, journey_id, true);

    // 发送NFT到用户
    if (profile::has_bounding_address(profile)) {
        transfer::transfer(journey_nft, profile::get_profile_bouding_addr(profile));
    } else {
        transfer::transfer(journey_nft, tx_context::sender(ctx));
    };

    // 发送铸造事件
    emit(JourneyMinted {
        journey_id,
        player: journey_data.player,
    });
}

// GETTER
public fun journey_exists(journey_id: ID, game_state: &GameState): bool {
    table::contains(&game_state.journey_records, journey_id)
}

public fun is_journey_minted(journey_id: ID, game_state: &GameState): bool {
    table::contains(&game_state.minted_journeys, journey_id)
}

public fun get_journey_details(
    journey_id: ID,
    game_state: &GameState,
): (address, String, bool, u64, String) {
    assert!(table::contains(&game_state.journey_records, journey_id), ERROR_JOURNEY_NOT_FOUND);

    let journey = table::borrow(&game_state.journey_records, journey_id);
    (journey.player, journey.name, journey.success, journey.rewards, journey.description)
}
