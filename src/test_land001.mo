/**
 * Module     : token.mo
 * Copyright  : 2021 DFinance Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : DFinance Team <hello@dfinance.ai>
 * Stability  : Experimental
 */

import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Types "./types";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Order "mo:base/Order";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Text "mo:base/Text";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Cycles "mo:base/ExperimentalCycles";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Bool "mo:base/Bool";

import Cap "./cap/Cap";
import Root "./cap/Root";
import Router "./cap/Router";
import CAPTypes "./cap/Types";
import IC "./cap/IC";

import ExtCore "../../../../ext/motoko/ext/Core";
import AID "../../../../ext/motoko/util/AccountIdentifier";


shared(msg) actor class Token(
    _logo: Text,
    _name: Text,
    _symbol: Text,
    _decimals: Nat8,
    _totalSupply: Nat,
    _owner: Principal,
    _fee: Nat
    ) = this {
    type Operation = Types.Operation;
    type TransactionStatus = Types.TransactionStatus;
    type TxRecord = Types.TxRecord;

    type Metadata = {
        logo : Text;
        name : Text;
        symbol : Text;
        decimals : Nat8;
        totalSupply : Nat;
        owner : Principal;
        fee : Nat;
    };

    // returns tx index or error msg
    public type TxReceipt = {
        #Ok: Nat;
        #Err: {
            #InsufficientAllowance;
            #InsufficientBalance;
            #ErrorOperationStyle;
            #Unauthorized;
            #LedgerTrap;
            #ErrorTo;
            #Other: Text;
            #BlockUsed;
            #TipTooBig;
            #AmountTooSmall;
        };
    };

    let limit = 10_000_000_000_000;
    type HttpRequest = Types.HttpRequest;
    type HttpResponse = Types.HttpResponse;
    private stable var debugMessage :Text = "";  


    stable var t : Text = "";
    public type Memo = Blob;

    private stable var owner_ : Principal = _owner;
    private stable var testUser : Principal = _owner;
    
    private stable var logo_ : Text = _logo;
    private stable var name_ : Text = _name;
    private stable var decimals_ : Nat8 = _decimals;
    private stable var symbol_ : Text = _symbol;
    private stable var totalSupply_ : Nat = _totalSupply;
    private stable var blackhole : Principal = Principal.fromText("aaaaa-aa");
    private stable var feeTo : Principal = owner_;
    private stable var fee : Nat = _fee;
    private stable var burnRate : Nat = 5;
    private stable var balanceEntries : [(Principal, Nat)] = [];
    private stable var _balancesState : [(AccountIdentifier, Balance)] = [(AID.fromPrincipal(owner_, null), totalSupply_)];

    private stable var excludeEntries : [(Principal, Nat)] = [];

    private stable var allowanceEntries : [(Principal, [(Principal, Nat)])] = [];
    private var balances = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);
    private var _balances : HashMap.HashMap<AccountIdentifier, Balance> = HashMap.fromIter(_balancesState.vals(), 0, AID.equal, AID.hash);


    private var excludeBurn = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);

    private var allowances = HashMap.HashMap<Principal, HashMap.HashMap<Principal, Nat>>(1, Principal.equal, Principal.hash);
    balances.put(owner_, totalSupply_);
    private stable let genesis : TxRecord = {
        caller = ?owner_;
        op = #mint;
        index = 0;
        from = blackhole;
        to = owner_;
        amount = totalSupply_;
        fee = 0;
        timestamp = Time.now();
        status = #succeeded;
    };



    /* CAP Code */
    type DetailValue = Root.DetailValue;
    type Event = Root.Event;
    type IndefiniteEvent = Root.IndefiniteEvent;
    let router_id = "lj532-6iaaa-aaaah-qcc7a-cai";
    private stable var rootBucket : ?Text = null;
    let ic: IC.ICActor = actor("aaaaa-aa");

    //let cap = Cap.Cap(router_id, rootBucketId);
    //let creationCycles : Nat = 1_000_000_000_000;

    public func id() : async Principal {
        return Principal.fromActor(this);
    };


     public shared(msg) func verifyCanister(pid : Principal) : async Text {
         
        let tokenContractId = Principal.toText(pid);
        let router: Router.Self = actor(router_id);

        let result = await router.get_token_contract_root_bucket({
            witness=false;
            canister=pid;
        });

            switch(result.canister) {
                case(null) {   
                    return "No Canister found";              
                };
                case (?canister) {
                    Principal.toText(canister);
                };
            };        

    }; 
     
     public shared(msg) func init() : async() {

        let pid = await id();
        let tokenContractId = Principal.toText(pid);

        let router: Router.Self = actor(router_id);

        let result = await router.get_token_contract_root_bucket({
            witness=false;
            canister=pid;
        });

            switch(result.canister) {
                case(null) {
                    let settings: IC.CanisterSettings = {
                        controllers = ?[Principal.fromText(router_id)];
                        compute_allocation = null;
                        memory_allocation = null;
                        freezing_threshold = null;
                    };

                    let params: IC.CreateCanisterParams = {
                        settings = ?settings
                    };

                    // Add cycles and perform the create call
                    Cycles.add(2_000_000_000_000);
                    let create_response = await ic.create_canister(params);

                    // Install the cap code
                    let canister = create_response.canister_id;
                    let router = (actor (router_id) : Router.Self);
                    await router.install_bucket_code(canister);

                    let result = await router.get_token_contract_root_bucket({
                        witness=false;
                        canister=pid;
                    });

                    switch(result.canister) {
                        case(null) {
                            // Debug.trap("Error while creating root bucket");
                            assert(false);
                        };
                        case(?canister) {
                            rootBucket := ?Principal.toText(canister);
                        };
                    };
                };
                case (?canister) {
                    rootBucket := ?Principal.toText(canister);
                };
            };        

    };    
    /* CAP Code ends here */
    /*************************/

    /*********************************************/
    //EXT Support
    type BalanceRequest = ExtCore.BalanceRequest;
    type BalanceResponse = ExtCore.BalanceResponse;
    type AccountIdentifier = ExtCore.AccountIdentifier;
    type Balance = ExtCore.Balance;
    
    public type CommonError = {
        #InvalidToken: TokenIdentifier;
        #Other : Text;
    };    
    public type TokenIdentifier  = Text;

    type ExtMetadata = Types.Metadata;

    private stable var EXT_METADATA : ExtMetadata = #fungible({
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        metadata = null;
    }); 


    public shared(msg) func setEXT() {
        assert(msg.caller == owner_);
        
        let TMP_EXT_METADATA : ExtMetadata = #fungible({
                name = name_;
                symbol = symbol_;
                decimals = decimals_;
                metadata = null;
            });  

        EXT_METADATA := TMP_EXT_METADATA;       

    };

    public query func metadata(token : TokenIdentifier) : async Result.Result<ExtMetadata, CommonError> {
        #ok(EXT_METADATA);
    };       

    /*********************************************/

    private stable var airdropcounter: Nat = 0;
    private stable var tipcounter: Nat = 0;  
    private stable var txcounter: Nat = 0;
    private var cap: ?Cap.Cap = null;

    private func addRecord(
        caller: Principal,
        op: Text, 
        details: [(Text, Root.DetailValue)]
        ): async () {
        

        let c = switch(cap) {
            case(?c) { c };
            case(_) { Cap.Cap(Principal.fromActor(this), 2_000_000_000_000) };
        };

        cap := ?c;
        let record: Root.IndefiniteEvent = {
            operation = op;
            details = details;
            caller = caller;
        };
        // don't wait for result, faster
        ignore c.insert(record);
       
    };

    private func _burn(from: Principal,amount: Nat) {

        totalSupply_ -= amount;

        txcounter += 1;
    };
    
    private func _chargeFee(from: Principal, fee: Nat) {
        if(fee > 0) {
            _transfer(from, feeTo, fee);
        };
    };

    

    private func _transfer(from: Principal, to: Principal, value: Nat) {
        let from_balance = _balanceOf(from);
        let from_balance_new : Nat = from_balance - value;
        if (from_balance_new != 0) { balances.put(from, from_balance_new); }
        else { balances.delete(from); };

        let to_balance = _balanceOf(to);
        let to_balance_new : Nat = to_balance + value;
        if (to_balance_new != 0) { balances.put(to, to_balance_new); };
    };



    private func _isExcluded(who: Principal) : Bool {
        switch (excludeBurn.get(who)) {
            case (?excluded) { return true; };
            case (_) { return false; };
        }
    };

    private func _allowance(owner: Principal, spender: Principal) : Nat {
        switch(allowances.get(owner)) {
            case (?allowance_owner) {
                switch(allowance_owner.get(spender)) {
                    case (?allowance) { return allowance; };
                    case (_) { return 0; };
                }
            };
            case (_) { return 0; };
        }
    };

    private func u64(i: Nat): Nat64 {
        Nat64.fromNat(i)
    };

    public shared(msg) func  burnTokens(from: Principal, burnTokens: Nat) {

        if(burnTokens > 0) {

            totalSupply_ -= burnTokens;

            ignore addRecord(
                msg.caller, "🔥 Self Burn ",
                [
                    ("from", #Principal(msg.caller)),
                    ("to", #Principal(blackhole)),
                    ("amount", #U64(u64(burnTokens))),
                    ("price", #U64(u64(burnTokens/100000000))),
                    ("fee", #U64(u64(0)))
                ]
            );            
            _transfer(msg.caller, blackhole, burnTokens);
        };
    };

    /*
    *   Core interfaces:
    *       update calls:
    *           transfer/transferFrom/approve
    *       query calls:
    *           logo/name/symbol/decimal/totalSupply/balanceOf/allowance/getMetadata
    *           historySize/getTransaction/getTransactions
    */
    public shared(msg) func tips(from: Principal, to: Principal, value: Nat,memo: Memo) : async TxReceipt {
        
       if (_balanceOf(msg.caller) < value) { return #Err(#InsufficientBalance); };
       if( value > 200000000000) { return #Err(#TipTooBig); };

        /***********************************************/
        tipcounter += 1;
        ignore addRecord(
            msg.caller, "🎁 Tip #"# Nat.toText(tipcounter),
            [
                ("from", #Principal(from)),
                ("to", #Principal(to)),
                ("price", #U64(u64(value/100000000))),
                ("amount", #U64(u64(value))),
                ("memo", #Slice(Blob.toArray(memo))),
                ("fee", #U64(u64(0)))
            ]
        );      
        _transfer(from, to, value);
        /***********************************************/

        txcounter += 1;
        
        return #Ok(tipcounter);
    };

    public shared(msg) func airdrops(to: Principal, value: Nat,airdrop: Text) : async TxReceipt {
        
        assert(msg.caller == owner_);

        if (_balanceOf(msg.caller) < value) { return #Err(#InsufficientBalance); };

        /***********************************************/
        airdropcounter += 1;

        var valueText = Nat.toText(value/100000000);

        ignore addRecord(
            msg.caller, "🪂 Airdrop "# airdrop # "-" # Nat.toText(airdropcounter),
            [
                ("from", #Principal(msg.caller)),
                ("to", #Principal(to)),
                ("amount", #U64(u64(value))),
                ("price", #U64(u64(value/100000000))),
                ("fee", #U64(u64(0)))
            ]
        );      
        _transfer(msg.caller, to, value);
        /***********************************************/

        txcounter += 1;
        
        return #Ok(airdropcounter);
    };



    /// Transfers value amount of tokens to Principal to.
    public shared(msg) func transfer(to: Principal, value: Nat) : async TxReceipt {
        if (_balanceOf(msg.caller) < value + fee) { return #Err(#InsufficientBalance); };

        var burnValue = (value*burnRate)/100;
        var transferAmount :Nat = (value - burnValue);

        _chargeFee(msg.caller, fee);

        /***********************************************/

        var isExcluded  :Bool = false;
        var compareBool :Bool = false;

        isExcluded := _isExcluded(msg.caller);


        if(Bool.equal(isExcluded,compareBool))
        {
            _transfer(msg.caller, blackhole, burnValue);
            totalSupply_ -= burnValue;

            ignore addRecord(
                msg.caller, "🔥 Transfer Burn "# Nat.toText(burnRate) #"%",
                [
                    ("from", #Principal(msg.caller)),
                    ("to", #Principal(blackhole)),
                    ("amount", #U64(u64(burnValue))),
                    ("price", #U64(u64(burnValue/100000000))),
                    ("fee", #U64(u64(0)))
                ]
            );
        }
        else
        {
            transferAmount := value;

            ignore addRecord(
                msg.caller, "⛔🔥 Transfer Burn excluded "# Nat.toText(burnRate) #"%",
                [
                    ("from", #Principal(msg.caller)),
                    ("to", #Principal(blackhole)),
                    ("amount", #U64(u64(0))),
                    ("price", #U64(u64(0))),
                    ("fee", #U64(u64(0)))
                ]
            );            
        };



        var feeText : Text = "0.01";
        ignore addRecord(
            msg.caller, "💰 Transfer Fees",
            [
                ("from", #Principal(msg.caller)),
                ("to", #Principal(feeTo)),
                ("amount", #U64(u64(fee))),
                ("price", #U64(u64(fee/100000000))),
                ("fee", #U64(u64(0)))
            ]
        );        
        /***********************************************/
        _transfer(msg.caller, to, transferAmount);

        ignore addRecord(
            msg.caller, "🔂 Transfer",
            [
                ("from", #Principal(msg.caller)),
                ("to", #Principal(to)),
                ("amount", #U64(u64(transferAmount))),
                ("price", #U64(u64(transferAmount/100000000))),
                ("fee", #U64(u64(fee)))
            ]
        );
        txcounter += 1;
        return #Ok(txcounter - 1);
    };

    /// Transfers value amount of tokens from Principal from to Principal to.
    public shared(msg) func transferFrom(from: Principal, to: Principal, value: Nat) : async TxReceipt {
        if (_balanceOf(from) < value + fee) { return #Err(#InsufficientBalance); };
        let allowed : Nat = _allowance(from, to);
        if (allowed < value + fee) { return #Err(#InsufficientAllowance); };
        _chargeFee(from, fee);
        _transfer(from, to, value);
        let allowed_new : Nat = allowed - value - fee;
        if (allowed_new != 0) {
            let allowance_from = Types.unwrap(allowances.get(from));
            allowance_from.put(msg.caller, allowed_new);
            allowances.put(from, allowance_from);
        } else {
            if (allowed != 0) {
                let allowance_from = Types.unwrap(allowances.get(from));
                allowance_from.delete(msg.caller);
                if (allowance_from.size() == 0) { allowances.delete(from); }
                else { allowances.put(from, allowance_from); };
            };
        };
        ignore addRecord(
            msg.caller, "🔄 Transfer",
            [
                ("from", #Principal(from)),
                ("to", #Principal(to)),
                ("amount", #U64(u64(value))),
                ("price", #U64(u64(value/100000000))),
                ("fee", #U64(u64(fee)))
            ]
        );
        var feeText : Text = "0.01";
        ignore addRecord(
            msg.caller, "💰 Transfer Fees",
            [
                ("from", #Principal(msg.caller)),
                ("to", #Principal(feeTo)),
                ("amount", #U64(u64(fee))),
                ("price", #U64(u64(fee/100000000))),
                ("fee", #U64(u64(0)))
            ]
        );        
        txcounter += 1;
        return #Ok(txcounter - 1);
    };

    /// Allows spender to withdraw from your account multiple times, up to the value amount.
    /// If this function is called again it overwrites the current allowance with value.
    public shared(msg) func approve(spender: Principal, value: Nat) : async TxReceipt {
        if(_balanceOf(msg.caller) < fee) { return #Err(#InsufficientBalance); };
        _chargeFee(msg.caller, fee);
        let v = value + fee;
        if (value == 0 and Option.isSome(allowances.get(msg.caller))) {
            let allowance_caller = Types.unwrap(allowances.get(msg.caller));
            allowance_caller.delete(spender);
            if (allowance_caller.size() == 0) { allowances.delete(msg.caller); }
            else { allowances.put(msg.caller, allowance_caller); };
        } else if (value != 0 and Option.isNull(allowances.get(msg.caller))) {
            var temp = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);
            temp.put(spender, v);
            allowances.put(msg.caller, temp);
        } else if (value != 0 and Option.isSome(allowances.get(msg.caller))) {
            let allowance_caller = Types.unwrap(allowances.get(msg.caller));
            allowance_caller.put(spender, v);
            allowances.put(msg.caller, allowance_caller);
        };
        ignore addRecord(
            msg.caller, "✅ Approve",
            [
                ("to", #Principal(spender)),
                ("from", #Principal(msg.caller)),
                ("amount", #U64(u64(value))),
                ("price", #U64(u64(value/100000000))),
                ("fee", #U64(u64(fee)))
            ]
        );
        var feeText : Text = "0.01";
        ignore addRecord(
            msg.caller, "💰 Approval Fees",
            [
                ("from", #Principal(msg.caller)),
                ("to", #Principal(feeTo)),
                ("amount", #U64(u64(fee))),
                ("price", #U64(u64(fee/100000000))),
                ("fee", #U64(u64(0)))
            ]
        );        
        txcounter += 1;
        return #Ok(txcounter - 1);
    };

    public shared(msg) func mint(to: Principal, value: Nat): async TxReceipt {
        if(msg.caller != owner_) {
            return #Err(#Unauthorized);
        };
        let to_balance = _balanceOf(to);
        totalSupply_ += value;
        balances.put(to, to_balance + value);
        ignore addRecord(
            msg.caller, "⛏️ Mint",
            [
                ("to", #Principal(to)),
                ("from", #Principal(blackhole)),
                ("amount", #U64(u64(value))),
                ("price", #U64(u64(value/100000000))),
                ("fee", #U64(u64(0)))
            ]
        );
        txcounter += 1;
        return #Ok(txcounter - 1);
    };


    public shared(msg) func burn(amount: Nat): async TxReceipt {
        let from_balance = _balanceOf(msg.caller);
        if(from_balance < amount) {
            return #Err(#InsufficientBalance);
        };
        totalSupply_ -= amount;
        balances.put(msg.caller, from_balance - amount);
        ignore addRecord(
            msg.caller, "🔥 Burn",
            [
                ("from", #Principal(msg.caller)),
                ("to", #Principal(blackhole)),
                ("amount", #U64(u64(amount))),
                ("price", #U64(u64(amount/100000000))),
                ("fee", #U64(u64(0)))
            ]
        );
        txcounter += 1;
        return #Ok(txcounter - 1);
    };


    public shared(msg) func burntTokens(): async Nat {
        var burnt :Nat = (100000000000000000 - totalSupply_);
        return burnt;
    };
    public query func CAPCanister() : async ?Text {
        return rootBucket;
    };


    public query func logo() : async Text {
        return logo_;
    };

    public query func name() : async Text {
        return name_;
    };

    public query func symbol() : async Text {
        return symbol_;
    };

    public query func decimals() : async Nat8 {
        return decimals_;
    };

    public query func totalSupply() : async Nat {
        return totalSupply_;
    };

    public query func getTokenFee() : async Nat {
        return fee;
    };

    public query func getBurnRate() : async Nat {
        return burnRate;
    };

    private func _balanceOf_dip20(who: Principal) : Nat {
        switch (balances.get(who)) {
            case (?balance) { return balance; };
            case (_) { return 0; };
        }
    };

    private func _balanceOf(who: Principal) : Nat {
        return _balance(who);
    };    

    private func _balance(who: Principal) : Nat {

        let aid = AID.fromPrincipal(who,null);

        switch (_balances.get(aid))
        {
            case (?balance) 
            {
                return balance;
            };
            case (_) 
            {
                return 0;
            };
        };   
    };
    public query func balance(who: BalanceRequest) : async BalanceResponse {

        switch(ExtCore.User.toPrincipal(who.user)) {
        
            case (?userPrincipal) {

               return #ok(_balanceOf(userPrincipal));
            };
            case (_) {

                let aid = ExtCore.User.toAID(who.user);
                    debugMessage := debugMessage # " address ="# aid;

                     switch (_balances.get(aid)) {
                        case (?balance) {
                            return #ok(balance);
                        };
                        case (_) {
                            return #ok(0);
                        };
                        };   
            };

        };
    };

    public shared(msg) func resetDebug() : async Text {
        debugMessage := "";
        return "Debug cleared!";
    };  

    public query func getDebug() : async Text {
        debugMessage;
    };  
    public query func balanceOf(who: Principal) : async Nat {
        return _balanceOf(who);
    };

    public query func allowance(owner: Principal, spender: Principal) : async Nat {
        return _allowance(owner, spender);
    };

    public query func getMetadata() : async Metadata {
        return {
            logo = logo_;
            name = name_;
            symbol = symbol_;
            decimals = decimals_;
            totalSupply = totalSupply_;
            owner = owner_;
            fee = fee;
        };
    };

    public query func tipSize() : async Nat {
        return tipcounter;
    };

    public query func airdropSize() : async Nat {
        return airdropcounter;
    };
    /// Get transaction history size
    public query func historySize() : async Nat {
        return txcounter;
    };

    public query func holdersSize() : async Nat {
        return balances.size();
    };
    

    /*
    *   Optional interfaces:
    *       setName/setLogo/setFee/setFeeTo/setOwner
    *       getUserTransactionsAmount/getUserTransactions
    *       getTokenInfo/getHolders/getUserApprovals
    */
    public shared(msg) func setName(name: Text) {
        assert(msg.caller == owner_);
        name_ := name;
    };

    public shared(msg) func setSymbol(symbol: Text) {
        assert(msg.caller == owner_);
        symbol_ := symbol;
    };    


    public shared(msg) func approveExclude(exclude: Principal) {
        assert(msg.caller == owner_);
        excludeBurn.put(exclude, 1);
    };


    public shared(msg) func setLogo(logo: Text) {
        assert(msg.caller == owner_);
        logo_ := logo;
    };

    public shared(msg) func setFeeTo(to: Principal) {
        assert(msg.caller == owner_);
        feeTo := to;
    };

    public shared(msg) func setBurnRate(_burnRate: Nat) {
        assert(msg.caller == owner_);
        burnRate := _burnRate;
    };

    public shared(msg) func setFee(_fee: Nat) {
        assert(msg.caller == owner_);
        fee := _fee;
    };

    public shared(msg) func setOwner(_owner: Principal) {
        assert(msg.caller == owner_);
        owner_ := _owner;
    };

    public type TokenInfo = {
        metadata: Metadata;
        feeTo: Principal;
        // status info
        historySize: Nat;
        deployTime: Time.Time;
        holderNumber: Nat;
        cycles: Nat;
    };
    public query func getTokenInfo(): async TokenInfo {
        {
            metadata = {
                logo = logo_;
                name = name_;
                symbol = symbol_;
                decimals = decimals_;
                totalSupply = totalSupply_;
                owner = owner_;
                fee = fee;
            };
            feeTo = feeTo;
            historySize = txcounter;
            deployTime = genesis.timestamp;
            holderNumber = balances.size();
            cycles = ExperimentalCycles.balance();
        }
    };

    public query func getHolders(start: Nat, limit: Nat) : async [(Principal, Nat)] {
        let temp =  Iter.toArray(balances.entries());
        func order (a: (Principal, Nat), b: (Principal, Nat)) : Order.Order {
            return Nat.compare(b.1, a.1);
        };
        let sorted = Array.sort(temp, order);
        let limit_: Nat = if(start + limit > temp.size()) {
            temp.size() - start
        } else {
            limit
        };
        let res = Array.init<(Principal, Nat)>(limit_, (owner_, 0));
        for (i in Iter.range(0, limit_ - 1)) {
            res[i] := sorted[i+start];
        };
        return Array.freeze(res);
    };

    public query func getPrincipal(start: Nat, limit: Nat) : async [Principal] {
        let temp =  Iter.toArray(balances.entries());
        func order (a: (Principal, Nat), b: (Principal, Nat)) : Order.Order {
            return Nat.compare(b.1, a.1);
        };
        let sorted = Array.sort(temp, order);
        let limit_: Nat = if(start + limit > temp.size()) {
            temp.size() - start
        } else {
            limit
        };
        let res = Array.init<(Principal, Nat)>(limit_, (owner_, 0));

        let onlyPrincipal = Array.init<(Principal)>(limit_, (owner_));
        //let onlyText      = Array.init<(Text)>(limit_, (AID.fromPrincipal(owner_, null)));
        let onlyText      = Array.init<(Nat)>(limit_, 0);

        for (i in Iter.range(0, limit_ - 1)) {
            res[i] := sorted[i+start];
        };

        var i = 0;
        for ((k, v) in res.vals()) {
            onlyPrincipal[i] := k;
            //onlyText[i] := AID.fromPrincipal(k, null);  
            let result = _balances.put(AID.fromPrincipal(k, null), v);
         
            onlyText[i] := v;  
            i +=1;
        };        

        return Array.freeze(onlyPrincipal);
    };    
    
    public shared(msg) func getAddress(start: Nat, limit: Nat) : async [Text] {
        let temp =  Iter.toArray(balances.entries());
        func order (a: (Principal, Nat), b: (Principal, Nat)) : Order.Order {
            return Nat.compare(b.1, a.1);
        };
        let sorted = Array.sort(temp, order);
        let limit_: Nat = if(start + limit > temp.size()) {
            temp.size() - start
        } else {
            limit
        };
        let res = Array.init<(Principal, Nat)>(limit_, (owner_, 0));

        let onlyPrincipal = Array.init<(Principal)>(limit_, (owner_));
        let onlyText      = Array.init<(Text)>(limit_, (AID.fromPrincipal(owner_, null)));
        //let onlyText      = Array.init<(Nat)>(limit_, 0);

        for (i in Iter.range(0, limit_ - 1)) {
            res[i] := sorted[i+start];
        };

        var i = 0;

        for ((k, v) in res.vals()) {
            onlyPrincipal[i] := k;

            testUser := k;

            //onlyText[i] := AID.fromPrincipal(k, null);  
            let result = _balances.put(AID.fromPrincipal(k, null), v);


            var z = balances.replace(k,v);
         
            debugMessage := debugMessage # " Address ="# AID.fromPrincipal(k, null);

            debugMessage := debugMessage # " Balance ="# Nat.toText(v);

            onlyText[i] := AID.fromPrincipal(k, null);  
            i +=1;
        };        

        return Array.freeze(onlyText);
    };    

    public query func getTestUser() : async Principal {
        return testUser;
    };


    public query func getAllowanceSize() : async Nat {
        var size : Nat = 0;
        for ((k, v) in allowances.entries()) {
            size += v.size();
        };
        return size;
    };

    public query func getUserApprovals(who : Principal) : async [(Principal, Nat)] {
        switch (allowances.get(who)) {
            case (?allowance_who) {
                return Iter.toArray(allowance_who.entries());
            };
            case (_) {
                return [];
            };
        }
    };

 /******************************************************************************/
    //Returns number of cycles in this container
    public query func get_cycles() : async Nat {
        return Cycles.balance();
    };

    public func acceptCycles() : async () {
        let available = Cycles.available();
        let accepted = Cycles.accept(available);
        assert (accepted == available);
    };

    public query func availableCycles() : async Nat {
        return Cycles.balance();
    };   
/********************************************************************/
    public func wallet_receive() : async { accepted: Nat64 } 
    {
        let available = Cycles.available();
        let accepted = Cycles.accept(Nat.min(available, limit));
        { accepted = Nat64.fromNat(accepted) };
    };

   public query func http_request(request: HttpRequest) : async HttpResponse {

        var holders: Nat = 0;

        let path = Iter.toArray(Text.tokens(request.url, #text("/")));
        
        var response_code: Nat16 = 200;
        var body = Blob.fromArray([]);
        var headers: [(Text, Text)] = [];

        if (path.size() >= 0) {
            
          response_code := 200;  
           
          headers := [("content-type", "text/plain")];
          body := Text.encodeUtf8 (
            "Token Name:                                " # name_ #"\n" #
            "Token Symbol:                              " # symbol_ #"\n" #
            "Token Standard:                            DIP20 \n" #
            "Trillion Balance:                          " # Nat.toText (Cycles.balance()/1000000000000) # "T\n" #
            "Cycle Balance:                             " # Nat.toText (Cycles.balance()) # "Cycles\n" #
            "Total Supply:                              " # Nat.toText(totalSupply_) #"\n" #
            "Transfer Fee:                              " # Nat.toText (fee) #"\n" #
            "Owner Principal:                           " # Principal.toText(owner_) # "\n" #
            "Debug Message:                             " # debugMessage # "\n" 
          );

        }; 


        return {
            body = body;
            headers = headers;
            status_code = response_code;
            streaming_strategy = null;
        };
    };

/********************************************************************/


    /*
    * upgrade functions
    */
    system func preupgrade() {
        balanceEntries := Iter.toArray(balances.entries());
        excludeEntries := Iter.toArray(excludeBurn.entries());

        var size : Nat = allowances.size();
        var temp : [var (Principal, [(Principal, Nat)])] = Array.init<(Principal, [(Principal, Nat)])>(size, (owner_, []));
        size := 0;
        for ((k, v) in allowances.entries()) {
            temp[size] := (k, Iter.toArray(v.entries()));
            size += 1;
        };
        allowanceEntries := Array.freeze(temp);
    };

    system func postupgrade() {
        balances := HashMap.fromIter<Principal, Nat>(balanceEntries.vals(), 1, Principal.equal, Principal.hash);
        balanceEntries := [];

        excludeBurn := HashMap.fromIter<Principal, Nat>(excludeEntries.vals(), 1, Principal.equal, Principal.hash);
        excludeEntries := [];

        for ((k, v) in allowanceEntries.vals()) {
            let allowed_temp = HashMap.fromIter<Principal, Nat>(v.vals(), 1, Principal.equal, Principal.hash);
            allowances.put(k, allowed_temp);
        };
        allowanceEntries := [];
    };
};
