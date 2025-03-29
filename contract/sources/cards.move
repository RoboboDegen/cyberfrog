module cyberfrog::cards;

use cyberfrog::version::{off_chain_validation, create_off_chain_validator, OffChainValidator};
use std::string::{Self, String};
use sui::clock::Clock;
use sui::event::emit;
use sui::table::{Self, Table};

const ERROR_CARD_NOT_FOUND: u64 = 1;
const ERROR_CARD_ALREADY_EXISTS: u64 = 2;
const ERROR_INVALID_VALIDATOR: u64 = 3;

public struct CardCreated has copy, drop {
    name: String,
    card_type: u8,
}

public struct CardUpdated has copy, drop {
    name: String,
    field: String,
}

public struct Card has drop, store {
    card_type: u8,
    attack: u8,
    defense: u8,
    consume: u8,
    description: String,
}

public struct CardRegistry has key {
    id: UID,
    cards: Table<String, Card>,
}

fun init(ctx: &mut TxContext) {
    let registry = CardRegistry {
        id: object::new(ctx),
        cards: table::new(ctx),
    };

    transfer::share_object(registry);
}

public fun register_card(
    card_type: u8,
    attack: u8,
    defense: u8,
    consume: u8,
    name: String,
    description: String,
    sig: vector<u8>,
    registry: &mut CardRegistry,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let last_time = clock.timestamp_ms();
    let off_chain_validator = create_off_chain_validator(last_time, ctx);
    assert!(
        off_chain_validation<OffChainValidator>(sig, off_chain_validator),
        ERROR_INVALID_VALIDATOR,
    );

    assert!(!table::contains(&registry.cards, name), ERROR_CARD_ALREADY_EXISTS);

    let card = Card {
        card_type,
        attack,
        defense,
        consume,
        description,
    };

    table::add(&mut registry.cards, name, card);

    emit(CardCreated {
        name,
        card_type,
    });
}

public fun update_card(
    name: String,
    attack: u8,
    defense: u8,
    consume: u8,
    description: String,
    sig: vector<u8>,
    registry: &mut CardRegistry,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // 验证签名
    let last_time = clock.timestamp_ms();
    let off_chain_validator = create_off_chain_validator(last_time, ctx);
    assert!(
        off_chain_validation<OffChainValidator>(sig, off_chain_validator),
        ERROR_INVALID_VALIDATOR,
    );

    assert!(table::contains(&registry.cards, name), ERROR_CARD_NOT_FOUND);

    let old_card = table::remove(&mut registry.cards, name);
    let Card {
        card_type,
        attack: _,
        defense: _,
        consume: _,
        description: _,
    } = old_card;

    let new_card = Card {
        card_type,
        attack,
        defense,
        consume,
        description,
    };

    table::add(&mut registry.cards, name, new_card);

    emit(CardUpdated {
        name,
        field: string::utf8(b"stats"),
    });
}

//可以用来加在profile中 todo
public fun is_valid_card(registry: &CardRegistry, card_name: String): bool {
    table::contains(&registry.cards, card_name)
}

// 获取卡片属性
public fun get_card_details(registry: &CardRegistry, name: String): (u8, u8, u8, u8, String) {
    assert!(table::contains(&registry.cards, name), ERROR_CARD_NOT_FOUND);

    let card = table::borrow(&registry.cards, name);
    (card.card_type, card.attack, card.defense, card.consume, card.description)
}

// 获取卡片攻击力
public fun get_card_attack(registry: &CardRegistry, name: String): u8 {
    assert!(table::contains(&registry.cards, name), ERROR_CARD_NOT_FOUND);
    table::borrow(&registry.cards, name).attack
}

// 获取卡片防御力
public fun get_card_defense(registry: &CardRegistry, name: String): u8 {
    assert!(table::contains(&registry.cards, name), ERROR_CARD_NOT_FOUND);
    table::borrow(&registry.cards, name).defense
}

// 获取卡片消耗
public fun get_card_consume(registry: &CardRegistry, name: String): u8 {
    assert!(table::contains(&registry.cards, name), ERROR_CARD_NOT_FOUND);
    table::borrow(&registry.cards, name).consume
}

// 获取卡片描述
public fun get_card_description(registry: &CardRegistry, name: String): String {
    assert!(table::contains(&registry.cards, name), ERROR_CARD_NOT_FOUND);
    table::borrow(&registry.cards, name).description
}

// 获取卡片类型
public fun get_card_type(registry: &CardRegistry, name: String): u8 {
    assert!(table::contains(&registry.cards, name), ERROR_CARD_NOT_FOUND);
    table::borrow(&registry.cards, name).card_type
}
