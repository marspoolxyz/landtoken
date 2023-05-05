/**
 * Module     : types.mo
 * Copyright  : 2021 DFinance Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : DFinance Team <hello@dfinance.ai>
 * Stability  : Experimental
 * Changed    : Adapted operations and OpRecord for NFT purposes, ERC 721. Added types to handle http_request and transaction_notification
 */

import Time "mo:base/Time";
import Blob "mo:base/Blob";

module {
    /// Update call operations
    public type Operation = {
        #mint;
        #purchase;
        #transfer;
        #list;
        #delist;
        #init;
    };
    /// Update call operation record fields
    public type OpRecord = {
        caller: Principal;
        op: Operation;
        index: Nat;
        from: ?Principal;
        to: ?Principal;
        tokenId: Nat;
        price: ?Nat64;
        timestamp: Time.Time;
    };

    public type Property = {
        name: Text;
        value: Text;
    };

    public type PropertyDesc = {
        name: Text;
        values: [Text];
    };

    public type TokenData = {
        id: Nat;
        data: [Nat8];
        contentType: Text;
    };
    public type TokenBlob = {
        id: Nat;
        data: Blob;
        contentType: Text;
    };
    public type TokenPrice = {
        price: Nat64;
        accountID: Text;
    };

    public type TokenOwnerData = {
        id: Nat;
        data: Principal;
        contentType: Text;
    };

    public type TokenStorage = {
        id: Nat;
        url: Text;
        name: Text;
        desc: Text;
        var owner: Principal;
        properties: [Property];
        date_of_birth: Time.Time;
        storage_canister: Text;
    };

    //Used for transfering token data
    public type TokenDesc = {
        id: Nat;
        url: Text;
        name: Text;
        desc: Text;
        owner: Principal;
        properties: [Property];
        date_of_birth: Time.Time;
        storage_canister: Text;
    };

    public type RarirtyRequest = {
        name: Text;
        desc: Text;
        properties: [Property];
 
    };

    
    public type MintRequest = {
        name: Text;
        url: Text;
        dataurl: Text;
        desc: Text;
        properties: [Property];
        data: [Nat8];
        contentType: Text;
        accountid:Text;
        storage_canister: Text;
    };

    //
    // Payment notification endpoint, called by ledger
    //

    public type Result = {
        #Ok : Text;
        #Err: Text;
    };

    public type ICPTs = {
        e8s: Nat64;
    };
    public type TransactionNotification = {
        to: Principal;
        to_subaccount: ?Nat8;
        from: Principal;
        from_subaccount: ?Nat8;
        memo: Nat64;
        amount : ICPTs;
        block_height : Nat64;
    };

    public type Listing = {
        owner: Principal;
        tokenId: Nat;
        price: Nat64;
        timestamp: Time.Time;
    };

    //
    //Http Request and Response
    //

    public type HttpRequest = {
        body: Blob;
        headers: [HeaderField];
        method: Text;
        url: Text;
    };

    public type HeaderField = (Text, Text);

    public type HttpResponse = {
        body: Blob;
        headers: [HeaderField];
        status_code: Nat16;
        streaming_strategy: ?StreamingStrategy;
    };
    
    public type StreamingCallbackToken =  {
        content_encoding: Text;
        index: Nat;
        key: Text;
        sha256: ?Blob;
    };

    public type StreamingStrategy = {
        #Callback: {
            callback: query (StreamingCallbackToken) -> async (StreamingCallbackResponse);
            token: StreamingCallbackToken;
        };
    };

    public type StreamingCallbackResponse = {
        body: Blob;
        token: ?StreamingCallbackToken;
    };
};    