/**
 * Module     : types.mo
 * Copyright  : 2021 DFinance Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : DFinance Team <hello@dfinance.ai>
 * Stability  : Experimental
 */

import Time "mo:base/Time";
import P "mo:base/Prelude";
import Blob "mo:base/Blob";

module {
    /// Update call operations
    public type Operation = {
        #mint;
        #burn;
        #transfer;
        #transferFrom;
        #approve;
    };
    public type TransactionStatus = {
        #succeeded;
        #inprogress;
        #failed;
    };

    public type Metadata = {
        #fungible : {
        name : Text;
        symbol : Text;
        decimals : Nat8;
        metadata : ?Blob;
        };
        #nonfungible : {
        metadata : ?Blob;
        };
    };        
    /// Update call operation record fields
    public type TxRecord = {
        caller: ?Principal;
        op: Operation;
        index: Nat;
        from: Principal;
        to: Principal;
        amount: Nat;
        fee: Nat;
        timestamp: Time.Time;
        status: TransactionStatus;
    };


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

    public type StreamingStrategy = {
        #Callback: {
            callback: query (StreamingCallbackToken) -> async (StreamingCallbackResponse);
            token: StreamingCallbackToken;
        };
    };
    public type StreamingCallbackToken =  {
        content_encoding: Text;
        index: Nat;
        key: Text;
        sha256: ?Blob;
    };
    public type StreamingCallbackResponse = {
        body: Blob;
        token: ?StreamingCallbackToken;
    };    
    public func unwrap<T>(x : ?T) : T =
        switch x {
            case null { P.unreachable() };
            case (?x_) { x_ };
        };
};    
