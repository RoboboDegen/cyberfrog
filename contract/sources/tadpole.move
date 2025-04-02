module cyberfrog::tadpole;

use sui::coin::{Self, TreasuryCap};
use sui::event::emit;
use sui::token::{Self, TokenPolicy, Token};
use sui::url::new_unsafe_from_bytes;

const DECIMALS: u8 = 0;
const SYMBOLS: vector<u8> = b"TAD";
const NAME: vector<u8> = b"Tadpole";
const DESCRIPTION: vector<u8> = b"Tadpole Token";
const ICON_URL: vector<u8> = b"https://"; // Coin / Token Icon

// ------ Errors -----------
const EWrongAmount: u64 = 0;

public struct TADPOLE has drop {}

public struct AdminCap has key, store {
    id: UID,
}

public struct TADTokenCap has key {
    id: UID,
    cap: TreasuryCap<TADPOLE>,
}

// ------ Events ---------
public struct PurchaseEvent has copy, drop {
    buyer: address,
    price: u64,
}

// ------ Functions ---------
fun init(otw: TADPOLE, ctx: &mut TxContext) {
    let deployer = ctx.sender();
    let admin_cap = AdminCap { id: object::new(ctx) };
    transfer::public_transfer(admin_cap, deployer);

    let (treasury_cap, metadata) = coin::create_currency<TADPOLE>(
        otw,
        DECIMALS,
        SYMBOLS,
        NAME,
        DESCRIPTION,
        option::some(new_unsafe_from_bytes(ICON_URL)),
        ctx,
    );

    let (mut policy, cap) = token::new_policy<TADPOLE>(
        &treasury_cap,
        ctx,
    );

    let token_cap = TADTokenCap {
        id: object::new(ctx),
        cap: treasury_cap,
    };

    token::allow(&mut policy, &cap, token::spend_action(), ctx);
    token::share_policy<TADPOLE>(policy);
    transfer::share_object(token_cap);
    transfer::public_transfer(cap, deployer);
    transfer::public_freeze_object(metadata);
}

public fun send_tad(
    _admin: &AdminCap,
    tad_token_cap: &mut TADTokenCap,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    let tad_token = token::mint(&mut tad_token_cap.cap, amount, ctx);
    let req = token::transfer<TADPOLE>(tad_token, recipient, ctx);
    token::confirm_with_treasury_cap<TADPOLE>(
        &mut tad_token_cap.cap,
        req,
        ctx,
    );
}

public(package) fun purchase(
    payment: Token<TADPOLE>,
    price: u64,
    token_prolicy: &mut TokenPolicy<TADPOLE>,
    ctx: &mut TxContext,
) {
    assert!(token::value<TADPOLE>(&payment) == price, EWrongAmount);
    let req = token::spend(payment, ctx);
    token::confirm_request_mut(token_prolicy, req, ctx);
    emit(PurchaseEvent {
        buyer: ctx.sender(),
        price: price,
    });
}

// ------ Admin Functions ---------
// for token::flush
public fun treasury_borrow_mut(
    _admin: &AdminCap,
    tad_token_cap: &mut TADTokenCap,
): &mut TreasuryCap<TADPOLE> {
    &mut tad_token_cap.cap
}
