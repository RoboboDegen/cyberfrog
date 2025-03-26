module cyberfrog::pool;

use sui::{
    balance::{Self, Balance},
    coin::{Self, Coin},
    table::{Self, Table},
    event::emit,
};

use std::{
    type_name::{Self, TypeName},
};

use cyberfrog::version::{SuperAdminCap, Validators, check_validator};
use cyberfrog::profile::{Profile,get_profile_token,edit_token,get_profile_bouding_addr};

// Events
public struct PoolCreated has copy, drop {
    pool_id: ID,
    coin_type: TypeName,
}

public struct PoolDeposit has copy, drop {
    pool_id: ID,
    amount: u64,
}

public struct PoolWithdraw has copy, drop {
    pool_id: ID,
    amount: u64,
}

// Errors
const ERROR_POOL_EXISTS: u64 = 1;
const ERROR_POOL_NOT_FOUND: u64 = 2;
const ERROR_INSUFFICIENT_BALANCE: u64 = 3;
const ERROR_INVALID_VALIDATOR: u64 = 4;

public struct State has key {
    id: UID,
    pools: Table<TypeName, u64>,
}

public struct Pool<phantom T> has key {
    id: UID,
    balance: Balance<T>,
}

fun init(ctx: &mut TxContext) {
    let state = State {
        id: object::new(ctx),
        pools: table::new(ctx),
    };
    transfer::share_object(state);
}

public fun create_pool<T: drop>(_: &SuperAdminCap, ctx: &mut TxContext, state: &mut State) {
    let type_name = type_name::get<T>();
    assert!(!table::contains(&state.pools, type_name), ERROR_POOL_EXISTS);

    let pool = Pool<T> {
        id: object::new(ctx),
        balance: balance::zero(),
    };
    table::add(&mut state.pools, type_name, 0);
    
    emit(PoolCreated {
        pool_id: pool.id.to_inner(),
        coin_type: type_name,
    });
    
    transfer::share_object(pool);
}

public fun deposit<T>(pool: &mut Pool<T>, coin: Coin<T>, state: &mut State) {
    let amount = coin::value(&coin);
    let balance = coin::into_balance(coin);
    balance::join(&mut pool.balance, balance);
    let pool_id = pool.id.to_inner();
    let type_name = type_name::get<T>();
    assert!(table::contains(&state.pools, type_name), ERROR_POOL_NOT_FOUND);
    let pool_amount = table::borrow_mut(&mut state.pools, type_name);
    *pool_amount = *pool_amount + amount;
    
    emit(PoolDeposit {
        pool_id,
        amount,
    });
}

public fun withdraw_by_admin<T>(
    _: &SuperAdminCap,
    pool: &mut Pool<T>,
    amount: u64,
    state: &mut State,
    ctx: &mut TxContext
): Coin<T> {
    assert!(balance::value(&pool.balance) >= amount, ERROR_INSUFFICIENT_BALANCE);
    
    let withdraw_balance = balance::split(&mut pool.balance, amount);
    let coin = coin::from_balance(withdraw_balance, ctx);
    let pool_id = pool.id.to_inner(); 
    let type_name = type_name::get<T>();
    assert!(table::contains(&state.pools, type_name), ERROR_POOL_NOT_FOUND);
    let pool_amount = table::borrow_mut(&mut state.pools, type_name);
    *pool_amount = *pool_amount - amount;
    emit(PoolWithdraw {
        pool_id,
        amount,
    });
    
    coin
}

public fun withdraw<T, U: drop>(
    pool: &mut Pool<T>,
    amount: u64,
    profile: &mut Profile,
    state: &mut State,
    validators: &Validators,
    ctx: &mut TxContext
) {
    assert!(check_validator<U>(validators), ERROR_INVALID_VALIDATOR);
    let balance_value = balance::value(&pool.balance);
    let profile_token = get_profile_token(profile, type_name::get<T>());
    assert!(profile_token >= amount, ERROR_INSUFFICIENT_BALANCE);
    assert!(balance_value >= amount, ERROR_INSUFFICIENT_BALANCE);

    let withdraw_balance = balance::split(&mut pool.balance, amount);
    let coin = coin::from_balance(withdraw_balance, ctx);
    let pool_id = pool.id.to_inner(); 
    let type_name = type_name::get<T>();
    assert!(table::contains(&state.pools, type_name), ERROR_POOL_NOT_FOUND);
    let pool_amount = table::borrow_mut(&mut state.pools, type_name);
    *pool_amount = *pool_amount - amount;

    edit_token<U>(profile, type_name, profile_token - amount, validators);
    
    let bouding_addr = get_profile_bouding_addr(profile);

    transfer::public_transfer(coin, bouding_addr);

    emit(PoolWithdraw {
        pool_id,
        amount,
    });
}   


// Getter
public fun balance<T>(pool: &Pool<T>): u64 {
    balance::value(&pool.balance)
}