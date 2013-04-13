%%%
%%% Peter Norvig's 5-card Poker hand evaluator, ported to Erlang.
%%%

-module(poker).
-export([hand_rank/1, sort_hands/1, winner/1]).

%%% Hand is a list of 2-char strings, i.e. ["6H","3D","AS","TH","JC"].

%% Function returns the list of hand's card ranks, sorted in desc order.
card_ranks(Hand) ->
    Ranks = lists:reverse(lists:sort(lists:map(fun card_rank/1, Hand))),
    ace_low_card_ranks(Ranks).

%% Wheel case (see tests at the bottom).
ace_low_card_ranks([14,5,4,3,2]) -> [5,4,3,2,1];
ace_low_card_ranks(Ranks) -> Ranks.

%% 2-char string in reality is a list of 2 numbers, i.e.
%% Ace of Hearts: "AH" = [$A,$H] = [65,72]
card_rank([$A,_]) -> 14;
card_rank([$K,_]) -> 13;
card_rank([$Q,_]) -> 12;
card_rank([$J,_]) -> 11;
card_rank([$T,_]) -> 10;
card_rank([R ,_]) -> R - 48.

% To avoid nested case-clauses, we pass a hand through a chain of
% functions until one of them returns a 'defined' value.
% Because of that, each function takes two arguments, Ranks and Hand,
% although it usually needs only one.

hand_rank(Hand) ->
    hand_rank(card_ranks(Hand), Hand).

hand_rank(Ranks, Hand) ->
    hand_rank(Ranks, Hand,
        [
            fun straight_flush/2,
            fun four_of_kind/2,
            fun full_house/2,
            fun flush/2,
            fun straight/2,
            fun three_of_kind/2,
            fun two_pair/2,
            fun pair/2,
            fun high_card/2
        ]).

hand_rank(Ranks, Hand, [F|Fs]) ->
    hand_rank2(F(Ranks, Hand), Ranks, Hand, Fs).
hand_rank2(undefined, Ranks, Hand, Fs) ->
    hand_rank(Ranks, Hand, Fs);
hand_rank2(Rank, _, _, _) -> Rank.

% Functions evaluating specific hand combinations.
% Return vector-value of the hand or 'undefined'.

straight_flush(Ranks, Hand) ->
    straight_flush2(straight(Ranks,Hand), flush(Ranks,Hand)).
straight_flush2([4,R], [5|_]) -> [8, R];
straight_flush2(_,_) -> undefined.

four_of_kind([H,L,L,L,L], _) -> [7, L, H];
four_of_kind([H,H,H,H,L], _) -> [7, H, L];
four_of_kind(_,_) -> undefined.

full_house([H,H,H,L,L], _) -> [6, H, L];
full_house([H,H,L,L,L], _) -> [6, L, H];
full_house(_,_) -> undefined.

flush(Ranks, [[_,S], [_,S], [_,S], [_,S], [_,S]]) -> [5 | Ranks];
flush(_,_) -> undefined.

straight([R1, R2, R3, R4, R5], _) when R1 == R2+1,
                                       R2 == R3+1,
                                       R3 == R4+1,
                                       R4 == R5+1 -> [4, R1];
straight(_,_) -> undefined.

three_of_kind([R,R,R,_,_] = Ranks, _) -> [3, R | Ranks];
three_of_kind([_,R,R,R,_] = Ranks, _) -> [3, R | Ranks];
three_of_kind([_,_,R,R,R] = Ranks, _) -> [3, R | Ranks];
three_of_kind(_,_) -> undefined.

two_pair([H,H,L,L,_] = Ranks, _) -> [2, H, L | Ranks];
two_pair([H,H,_,L,L] = Ranks, _) -> [2, H, L | Ranks];
two_pair([_,H,H,L,L] = Ranks, _) -> [2, H, L | Ranks];
two_pair(_,_) -> undefined.

pair(Ranks, _) -> pair2(lists:usort(Ranks), Ranks).
pair2([_,_,_,_] = UniqRanks, Ranks) -> [1, hd(Ranks -- UniqRanks) | Ranks];
pair2(_,_) -> undefined.

high_card(Ranks, _) -> [0 | Ranks].

%% To find a winning hand, we just sort hands according to their ranks

sort_hands(Hands) ->
    lists:sort(fun compare/2, Hands).

% Better hand first
compare(Hand1, Hand2) ->
    hand_rank(Hand2) =< hand_rank(Hand1).

winner(Hands) ->
    hd(sort_hands(Hands)).

%%% ===========================================================================
%%% Unit tests
%%% ===========================================================================

-include_lib("eunit/include/eunit.hrl").

list_to_hand(HandStr) ->
    re:split(HandStr, " ", [{return,list}]).

card_ranks_test() ->
    ?assertEqual([6,5,4,3,2], card_ranks(list_to_hand("2H 3H 4H 5H 6H"))),
    ?assertEqual([5,4,3,2,1], card_ranks(list_to_hand("2S 3H 4C 5D AH"))).

hand_rank_result(HandStr) ->
    Hand = list_to_hand(HandStr),
    Ranks = card_ranks(Hand),
    hand_rank(Ranks, Hand).

straight_flush_test() ->
    ?assertEqual([8,6], hand_rank_result("2H 4H 6H 3H 5H")),
    ?assertEqual([8,5], hand_rank_result("2H 4H AH 3H 5H")),
    ?assertEqual([8,14], hand_rank_result("TH QH AH KH JH")).

four_of_kind_test() ->
    ?assertEqual([7,2,6], hand_rank_result("2H 2D 6H 2S 2C")),
    ?assertEqual([7,6,2], hand_rank_result("2H 6D 6H 6S 6C")).

full_house_test() ->
    ?assertEqual([6,6,2], hand_rank_result("2H 6D 6H 2S 6C")),
    ?assertEqual([6,2,6], hand_rank_result("2H 2D 6H 2S 6C")).

flush_test() ->
    ?assertEqual([5,6,6,5,4,2], hand_rank_result("2H 4H 6H 6H 5H")).

straight_test() ->
    ?assertEqual([4,6], hand_rank_result("2H 4H 6D 3H 5H")).

three_of_kind_test() ->
    ?assertEqual([3,2,14,4,2,2,2], hand_rank_result("2H 4H 2D AH 2S")).

two_pair_test() ->
    ?assertEqual([2,6,2,13,6,6,2,2], hand_rank_result("2H KD 6H 2S 6C")).

pair_test() ->
    ?assertEqual([1,2,13,12,6,2,2], hand_rank_result("2H KD QH 2S 6C")).

high_card_test() ->
    ?assertEqual([0,14,13,12,6,2], hand_rank_result("AH KD QH 2S 6C")).

sort_hands_test() ->
    RoyalFlushSpades        = list_to_hand("AS QS TS JS KS"),
    RoyalFlushClubs         = list_to_hand("AC JC TC QC KC"),
    StraightFlushTenHigh    = list_to_hand("7C 6C TC 8C 9C"),
    StraightFlushSevenHigh  = list_to_hand("7D 4D 5D 3D 6D"),
    SteelWheel              = list_to_hand("3H 4H 5H AH 2H"),
    NineQuadsJackKicker     = list_to_hand("9H JD 9S 9C 9D"),
    NineQuadsFiveKicker     = list_to_hand("9H 5S 9S 9C 9D"),
    QueensOverNines         = list_to_hand("9H QS QD QC 9D"),
    QueensOverThrees        = list_to_hand("QH 3S QD QC 3D"),
    KingFlush               = list_to_hand("JS 2S 4S KS 7S"),
    QueenFlushJackHigh      = list_to_hand("JC 2C QC 5C 7C"),
    QueenFlushEightHigh     = list_to_hand("8C 2C QC 5C 7C"),
    QueenFlushEightHighSix  = list_to_hand("8C 2C QC 5C 6C"),
    StraightNineHigh        = list_to_hand("7C 6S 5D 8H 9C"),
    StraightSixHigh         = list_to_hand("2D 4C 5S 3D 6H"),
    Wheel                   = list_to_hand("3H 4H 5D AD 2S"),
    ThreeQueens             = list_to_hand("5H 4C QD QC QS"),
    ThreeTensSixKicker      = list_to_hand("5H TH 6D TC TS"),
    ThreeTensFiveKicker     = list_to_hand("5H TH 4D TC TS"),
    ThreeTensFiveKicker3    = list_to_hand("5H TH 3D TC TS"),
    KingsOverNines          = list_to_hand("9H KH 9D KC 2S"),
    JackOverFoursAceKicker  = list_to_hand("4D 4H JD JH AC"),
    JackOverFoursTenKicker  = list_to_hand("4D 4H JD JH TS"),
    TwoAces                 = list_to_hand("AD 4H JD 7H AS"),
    TwoTensAceHigh          = list_to_hand("AD TH TD 7H 8S"),
    TwoTensSixHigh          = list_to_hand("6D TH TD 4H 5S"),
    TwoTensSixHigh4         = list_to_hand("6D TH TD 4H 3S"),
    TwoTensSixHigh42        = list_to_hand("6D TH TD 4H 2S"),
    AceHigh                 = list_to_hand("6D AH TD 4H 2S"),
    JackHigh8               = list_to_hand("8D 5H 7D JH 2S"),
    JackHigh86              = list_to_hand("8D 5H 6D JH 2S"),
    JackHigh864             = list_to_hand("8D 4H 6D JH 2S"),
    ?assertEqual(
        [
            RoyalFlushSpades,
            RoyalFlushClubs,
            StraightFlushTenHigh,
            StraightFlushSevenHigh,
            SteelWheel,
            NineQuadsJackKicker,
            NineQuadsFiveKicker,
            QueensOverNines,
            QueensOverThrees,
            KingFlush,
            QueenFlushJackHigh,
            QueenFlushEightHigh,
            QueenFlushEightHighSix,
            StraightNineHigh,
            StraightSixHigh,
            Wheel,
            ThreeQueens,
            ThreeTensSixKicker,
            ThreeTensFiveKicker,
            ThreeTensFiveKicker3,
            KingsOverNines,
            JackOverFoursAceKicker,
            JackOverFoursTenKicker,
            TwoAces,
            TwoTensAceHigh,
            TwoTensSixHigh,
            TwoTensSixHigh4,
            TwoTensSixHigh42,
            AceHigh,
            JackHigh8,
            JackHigh86,
            JackHigh864
        ],
        sort_hands([
            StraightNineHigh,
            ThreeQueens,
            AceHigh,
            QueenFlushEightHighSix,
            TwoTensSixHigh4,
            ThreeTensFiveKicker3,
            JackHigh864,
            QueensOverNines,
            KingFlush,
            ThreeTensFiveKicker,
            NineQuadsFiveKicker,
            TwoAces,
            StraightFlushSevenHigh,
            JackHigh86,
            TwoTensSixHigh,
            TwoTensAceHigh,
            JackHigh8,
            QueenFlushEightHigh,
            QueensOverThrees,
            JackOverFoursTenKicker,
            Wheel,
            SteelWheel,
            NineQuadsJackKicker,
            StraightSixHigh,
            StraightFlushTenHigh,
            ThreeTensSixKicker,
            RoyalFlushSpades,
            TwoTensSixHigh42,
            QueenFlushJackHigh,
            JackOverFoursAceKicker,
            KingsOverNines,
            RoyalFlushClubs
        ])
    ),
    ?assertEqual(SteelWheel, winner([Wheel, SteelWheel])).