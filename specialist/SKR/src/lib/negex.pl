/****************************************************************************
*
*                          PUBLIC DOMAIN NOTICE                         
*         Lister Hill National Center for Biomedical Communications
*                      National Library of Medicine
*                      National Institues of Health
*           United States Department of Health and Human Services
*                                                                         
*  This software is a United States Government Work under the terms of the
*  United States Copyright Act. It was written as part of the authors'
*  official duties as United States Government employees and contractors
*  and thus cannot be copyrighted. This software is freely available
*  to the public for use. The National Library of Medicine and the
*  United States Government have not placed any restriction on its
*  use or reproduction.
*                                                                        
*  Although all reasonable efforts have been taken to ensure the accuracy 
*  and reliability of the software and data, the National Library of Medicine
*  and the United States Government do not and cannot warrant the performance
*  or results that may be obtained by using this software or data.
*  The National Library of Medicine and the U.S. Government disclaim all
*  warranties, expressed or implied, including warranties of performance,
*  merchantability or fitness for any particular purpose.
*                                                                         
*  For full details, please see the MetaMap Terms & Conditions, available at
*  https://metamap.nlm.nih.gov/MMTnCs.shtml.
*
***************************************************************************/

% negex initial implementation
% ./src/skr/negex.pl, Thu Jul 31 11:00:57 2008, edit by Will Rogers
% Author: Willie Rogers

% See https://code.google.com/p/negex/wiki/NegExTerms

:- module(negex,[
	compute_negex/5,
	do_negex/0,	 
	default_negex_semtypes/1,
	final_negation_template/6
	% generate_all_negex_output/1
	% generate_negex_output/1
   ]).

:- use_module(metamap(metamap_tokenization),[
        tokenize_text_utterly/2
   ]).

% :- use_module(metamap(metamap_utilities),[
% 	positions_overlap/2
%    ]).

:- use_module(skr(skr_utilities), [
	fatal_error/2,
	get_candidate_feature/3,
	get_all_candidate_features/3
   ]).

:- use_module(skr_lib(flatten), [
	flatten/2
   ]).

:- use_module(negex_triggers, [
	nega_phrase_tokens/2,
	negb_phrase_tokens/2,
	pnega_phrase_tokens/2,
	pnegb_phrase_tokens/2,
	pseudoneg_phrase_tokens/2,
	conj_phrase_tokens/2
   ]).

:- use_module(skr_lib(nls_lists),[
	get_from_list/3
   ]).

:- use_module(skr_lib(nls_strings),[
	split_string_completely/3
   ]).

:- use_module(skr_lib(nls_system),[
        control_option/1,
	control_value/2
   ]).

:- use_module(skr_lib(sicstus_utils), [
	concat_atom/3,
	sublist/2,
	substring/4,			       
	ttyflush/0
   ]).

:- use_module(library(lists), [
	append/2,
	last/2,
	select/3,
	subseq1/2
   ]).

:- use_module(library(sets), [
	disjoint/2,
	intersection/3,
	subtract/3
   ]).

:- use_module(library(system), [
	environ/2
   ]).

% These two predicates should be the ONLY instances
% where the negation/6 term appears explicitly.

% orig_negation_template is the initial form of negation/6 terms
% as they're initially created -- before they're merged
orig_negation_template(negation(Type, TriggerText, TriggerPosInfo,
				ConceptName, CUI, ConceptPosInfo),
		       Type, TriggerText, TriggerPosInfo,
		       ConceptName, CUI, ConceptPosInfo).

% final_negation_template is the final form of negation/5 terms
% after multiple concepts and CUIs from the same negation are merged
final_negation_template(negation(Type, TriggerText, TriggerPosInfo,
				 ConceptCUIList, ConceptPosInfo),
			Type, TriggerText, TriggerPosInfo,
			ConceptCUIList, ConceptPosInfo).
		  

% find all negated concepts
compute_negex(RawTokenList, Lines, PhraseList, NegationTerms, OutPhraseList) :-
	( compute_negex_1(RawTokenList, PhraseList, NegationTerms, OutPhraseList) ->
	  true
	; fatal_error('Negex failed on "~p".~n', [Lines]),
	  abort
	).

do_negex :-
 	( control_option(negex) ->
 	  true
 	; control_option(negex_trigger_file) ->
 	  true
 	; control_option(fielded_mmi_output) ->
 	  true
 	; control_value(negex_st_add, _) ->
 	  true
 	; control_value(negex_st_del, _) ->
 	  true
 	; control_value(negex_st_set, _)
 	).

compute_negex_1(RawTokenList, PhraseList, NegationTerms, OutPhraseList) :-
	% ( \+ control_option(machine_output),
	%   \+ control_option(fielded_mmi_output),
	%   \+ xml_output_format(_XMLFormat),
	%   \+ do_negex ->
	%   NegationTerms = []
	% ; environ('NEGEX_UTTERANCE_MAX_DIST', UtteranceMaxDistAtom),
	environ('NEGEX_UTTERANCE_MAX_DIST', UtteranceMaxDistAtom),
	atom_codes(UtteranceMaxDistAtom,    UtteranceMaxDistChars),
	number_codes(UtteranceMaxDistNum,   UtteranceMaxDistChars),
	environ('NEGEX_CONCEPT_MAX_DIST',   ConceptMaxDistAtom),
	atom_codes(ConceptMaxDistAtom,      ConceptMaxDistChars),
	number_codes(ConceptMaxDistNum,     ConceptMaxDistChars),
	% Split the token list for the entire utterance into a list of lists of tokens;
	% each sub-list contains all the tokens for a single utterance.
	% No longer needed
	% split_token_list(RawTokenList, [FirstUtteranceTokenList|_ListOfTokenLists]),
	get_first_utterance_tokens(RawTokenList, FirstUtteranceTokenList),
	token_negex(FirstUtteranceTokenList, PhraseList,
		    UtteranceMaxDistNum, ConceptMaxDistNum, NegationTerms0),
	flatten(NegationTerms0, NegationTerms),
	instantiate_negated_fields(PhraseList, NegationTerms),
	instantiate_negated_fields_nocui(PhraseList, NegationTerms, OutPhraseList).

% negex_aux([], [], _UtteranceMaxDist, _ConceptMaxDist, []).
% negex_aux([RawTokenList|ListOfTokenLists], [MMOutput|MMOutputList],
%           UtteranceMaxDist, ConceptMaxDist, [NegationTerm|NegationTerms]) :-
%         MMOutput = mm_output(_,_,_,_,_,_,DisambiguatedMMOPhraseList,_),
%         token_negex(RawTokenList, DisambiguatedMMOPhraseList,
%                     UtteranceMaxDist, ConceptMaxDist, NegationTerm),
%         negex_aux(ListOfTokenLists, MMOutputList, UtteranceMaxDist, ConceptMaxDist, NegationTerms).

% NegEx output should be generated IFF
% * --negex is on, and
% neither machine_output nor XML is on.
% generate_negex_output(NegationTerms) :-
% 	( do_negex,
% 	  \+ control_option(machine_output),
% 	  \+ control_option(fielded_mmi_output),
% 	  \+ xml_output_format(_XMLFormat) ->
% 	   format('NEGATIONS:~n', []),
% 	   generate_all_negex_output(NegationTerms),
% 	   nl
% 	; true
% 	).

% generate_all_negex_output([]).
% generate_all_negex_output([H|T]) :-
% 	generate_one_negex_output(H),
% 	generate_all_negex_output(T).
% 
% generate_one_negex_output(NegExTerm) :-
% 	final_negation_template(NegExTerm,
% 				NegationType, NegationTrigger, NegationPosInfo,
% 				ConceptCUIList, NegatedConceptPosInfo),
% 	display_negex_info('Negation Type:     ', NegationType),
% 	display_negex_info('Negation Trigger:  ', NegationTrigger),
% 	display_negex_info('Negation PosInfo:  ', NegationPosInfo),
% 	display_negex_info('Negated  Concept:  ', ConceptCUIList),
% 	display_negex_info('Concept  PosInfo:  ', NegatedConceptPosInfo),
% 	nl.

% display_negex_info(Header, Data) :-
% 	( atomic(Data) ->
% 	  display_negex_atom_info(Header, Data)
% 	; display_negex_list_info(Header, Data)
% 	).
% 
% display_negex_atom_info(Header, AtomData) :-
% 	format('~w~w~n', [Header,AtomData]).
% 
% display_negex_list_info(Header, ListData) :-
% 	format('~w', [Header]),
% 	ListData = [H|T],
% 	write_list_elements(T, H).
% 
% write_list_elements([], Datum) :-
% 	format('~w~n', [Datum]).
% write_list_elements([H|T], Datum) :-
% 	format('~w, ', [Datum]),
% 	write_list_elements(T, H).
 
% token based marking of nega (and pnega) negations
%
% 1. find negation phrase in tokenlist
% 2. extract tokens following negation phrase.
% 3. mark as negated concepts in phrase mappings references by extracted tokens.
%
% first attempt -- mostly exploration with using token based 
token_negex(RawTokenList, DisambiguatedMMOPhrases,
	    UtteranceMaxDist, ConceptMaxDist, ConsolidatedNegationTerms) :-
	% Remove field, label, pn, sn, pe, and ws tokens.
 	remove_nonuseful_tokens(RawTokenList, UsefulTokenList),
 	extract_atoms_from_tokenlist(UsefulTokenList, AtomList),
	% [ [nega, [not]] ... ]
 	get_negation_phrase_list(AtomList, NegationPhraseList0),
	sort(NegationPhraseList0, NegationPhraseList),
	generate_negation_terms_1(NegationPhraseList, DisambiguatedMMOPhrases,
				  UtteranceMaxDist, ConceptMaxDist,
				  UsefulTokenList, ConsolidatedNegationTerms).

generate_negation_terms_1([], _DisambiguatedMMOPhrases,
			  _UtteranceMaxDist, _ConceptMaxDist, _UsefulTokenList, []).
generate_negation_terms_1([H|T], DisambiguatedMMOPhrases,
			  UtteranceMaxDist, ConceptMaxDist,
			  UsefulTokenList, NegationTerms) :-
	NegationPhraseList = [H|T],
	% TriggerList = [trigger(nega,[tok(lc,"not","not",pos(83,86),pos(83,3))])]
	get_triggerlist(UsefulTokenList, NegationPhraseList, TriggerList0),
	% PhraseMaps0 is a list of lists of the form [PhraseObject,Mappings];
	% PhraseObject is phrase(PhraseAtom, Syntax, StartPos/Length, ReplPos), and
	% Mappings is a list of the mappings generated from that phrase.
	list_phrases_with_candidates(DisambiguatedMMOPhrases, PhraseMaps0),
	% Keep only [PhraseObject,Mappings] lists in which
	% PhraseObject is head or verb, and Mappings is nonempty.
%	keep_useful_phrasemaps(PhraseMaps0, PhraseMaps),
	generate_negation_terms_2(PhraseMaps0, UsefulTokenList,
				  UtteranceMaxDist, ConceptMaxDist,
				  TriggerList0, NegationTerms).

generate_negation_terms_2([], _UsefulTokenList,
			  _UtteranceMaxDist, _ConceptMaxDist, _TriggerList0, []).
generate_negation_terms_2([H|T], UsefulTokenList,
			  UtteranceMaxDist, ConceptMaxDist,
			  TriggerList0, ConsolidatedNegationTerms) :-
	PhraseMaps = [H|T],
	extract_trigger_sequences(TriggerList0, TriggerSeqList0),
	remove_proper_subseqs(TriggerSeqList0, TriggerSeqList),
	keep_triggers_with_seqs(TriggerList0, TriggerSeqList, Triggers),
	list_concepts_and_tokens(PhraseMaps, UsefulTokenList, ConceptTokensPhraseMaps),
	list_concepts_for_triggers(Triggers, ConceptTokensPhraseMaps, NegationTerms0),
	block_negated_terms_overlapping_triggers(NegationTerms0, NegationTerms1), 
	remove_negation_terms_after_conjs(NegationTerms1, NegationTerms2),
	cull_negterms_eliminated_by_conj_and(UsefulTokenList, NegationTerms2, NegationTerms3),
	remove_spurious_negterms(NegationTerms3,
				 UtteranceMaxDist, ConceptMaxDist,
				 UsefulTokenList, NegationTerms),
	consolidate_negation_terms(NegationTerms, ConsolidatedNegationTerms).

block_negated_terms_overlapping_triggers([], []).
block_negated_terms_overlapping_triggers([H|T], Rest) :-
	orig_negation_template(H, _Type, _TriggerText, TriggerPosInfo,
			       _ConceptName, _CUI, ConceptPosInfo),
	( trigger_overlaps_concept(TriggerPosInfo, ConceptPosInfo) ->
	  Rest = NextRest
	; Rest = [H|NextRest]
	),
	block_negated_terms_overlapping_triggers(T, NextRest).

trigger_overlaps_concept(TriggerPosInfo, ConceptPosInfo) :-
	get_overall_start_and_end_pos(TriggerPosInfo,
				      FirstTriggerStartPos, LastTriggerEndPos),
	get_overall_start_and_end_pos(ConceptPosInfo,
				      FirstConceptStartPos, LastConceptEndPos),
	positions_overlap(FirstTriggerStartPos, LastTriggerEndPos,
			  FirstConceptStartPos, LastConceptEndPos).

get_overall_start_and_end_pos(AllPosInfo, FirstStartPos, LastEndPos) :-
	AllPosInfo = [FirstPosInfo|_],
	FirstPosInfo = FirstStartPos/_FirstLength,
	last(AllPosInfo, LastPosInfo),
	LastPosInfo = LastStartPos/LastLength,
	LastEndPos is LastStartPos + LastLength.
	
% See "Overlap Test" in https://en.wikipedia.org/wiki/Interval_tree
positions_overlap(StartPos1, EndPos1, StartPos2, EndPos2) :-
	% 1:    |-------------|
	% 2:         |-------------|
	( StartPos1 =< StartPos2,
	  StartPos2 < EndPos1 ->
	  true
	% 1:         |-------------|
	% 2:    |-------------|
	; StartPos1 < EndPos2,
	  EndPos2  =< EndPos1 ->
	  true
	% 1:        |----|
	% 2:    |-------------|
	; StartPos2 =< StartPos1,
	  StartPos1 < EndPos2 ->
	  true
	% 1:    |-------------|
	% 2:        |----|
	; StartPos2 < EndPos1,
	  EndPos1 =< EndPos2
	).

remove_nonuseful_tokens([], []).
remove_nonuseful_tokens([H|T], TokenListOut) :-
	( non_useful(H) ->
	  RestTokenListOut = TokenListOut
	; TokenListOut = [H|RestTokenListOut]
	),
	remove_nonuseful_tokens(T, RestTokenListOut).

non_useful(tok(TokenType,_,_,_,_)) :- nonuseful_token_type(TokenType).

nonuseful_token_type(field).
nonuseful_token_type(label).
nonuseful_token_type(pn).
nonuseful_token_type(sn).
nonuseful_token_type(pe).
nonuseful_token_type(ws).

% list tokens which correspond to the supplied PhraseMap
list_mapped_tokens([], _, []).
list_mapped_tokens([Token|RawTokenListIn], PhraseMap, MappedTokens) :-
	Token = tok(_Type,_String,_Nstring, _Pos0, pos(TokenStart,TokenLength)),	
	PhraseMap = phrase(_PhraseText,_Mincoman,_PhraseStartPos/_PhraseEndPos,_):CandidatesList,
%		     mappings(MapList)],
%	( maplist_contains_range(MapList, TokenStart, TokenLength) ->
	evlist_contains_range(CandidatesList, TokenStart, TokenLength),
	!,
	MappedTokens = [Token|RestMappedTokens],
	list_mapped_tokens(RawTokenListIn, PhraseMap, RestMappedTokens).
list_mapped_tokens([Token|RawTokenListIn], PhraseMap, MappedTokens) :-
	Token = tok(_Type,_String,_Nstring, _Pos0, pos(TokenStart,TokenLength)),	
	PhraseMap = phrase(_PhraseText,_Mincoman,PhraseStartPos/PhraseEndPos,_):_CandidatesList,
	positionlist_contains_range([PhraseStartPos/PhraseEndPos],TokenStart,TokenLength),
	!,
	MappedTokens = [Token|RestMappedTokens],
	list_mapped_tokens(RawTokenListIn, PhraseMap, RestMappedTokens).
list_mapped_tokens([_Token|RawTokenListIn], PhraseMap, MappedTokens) :-
	list_mapped_tokens(RawTokenListIn, PhraseMap, MappedTokens).

% maplist_contains_range([Map|MapList], TokenStart, TokenLength) :-
% 	Map = map(_score,EvList),
% 	( evlist_contains_range(EvList, TokenStart, TokenLength) ->
% 	  true
% 	; maplist_contains_range(MapList, TokenStart, TokenLength)
% 	).

evlist_contains_range([FirstCandidate|RestCandidates], TokenStart, TokenLength) :-
	get_candidate_feature(posinfo, FirstCandidate, PositionList),
	( positionlist_contains_range(PositionList, TokenStart, TokenLength) ->
	  true
	; evlist_contains_range(RestCandidates, TokenStart, TokenLength)
	).

%% Is the Token within the mapping?
%% These assumptions must hold:
%% (1)  TokenStart >= MappingStart and TokenStart < (MappingStart + MappingLength)
%% (2) (TokenStart + TokenLength) <= (MappingStart + MappingLength)

positionlist_contains_range([Position|Positionlist], TokenStart, TokenLength) :-
	Position = MappingStart/MappingLength,
	MappingEnd is (MappingStart + MappingLength + 1),
	TokenEnd is (TokenStart + TokenLength),
	( TokenStart >= MappingStart,
	  TokenStart < MappingEnd,
	  TokenEnd < MappingEnd ->
	  true
	; positionlist_contains_range(Positionlist, TokenStart, TokenLength)
	).

% extract_tokens_from_string(PhraseText,Tokens)
list_concepts_and_tokens([], _, []).
list_concepts_and_tokens([PhraseMap|PhraseMaps], RawTokenListIn, ConceptTokensPhraseMap) :-
	list_mapped_tokens(RawTokenListIn, PhraseMap, MappedTokens),
	( MappedTokens = [] ->
	  ConceptTokensPhraseMap = RestConceptTokensPhraseMap
	  % PhraseObject = _,
	  % Mappings = _
	; PhraseMap = PhraseObject:CandidateList,
	  % reversed order of args from QP library version!
	  last(MappedTokens, LastMappedToken),
	  ConceptTokensPhraseMap = [[LastMappedToken,PhraseObject,CandidateList]
				    |RestConceptTokensPhraseMap]
	),
	list_concepts_and_tokens(PhraseMaps, RawTokenListIn, RestConceptTokensPhraseMap).

% build a list of normalized atoms from list of tokens.
extract_atoms_from_tokenlist([], []).
extract_atoms_from_tokenlist([Token|RestTokens], [Atom|RestAtoms]) :-
	Token = tok(_Type,_UnNormString,String,_StartPos,_EndPos),
	atom_codes(Atom, String),
	extract_atoms_from_tokenlist(RestTokens, RestAtoms).

% atomize_strings/2 - convert a list of strings to a list of atoms
atomize_strings([], []).
atomize_strings([String|Stringlist], [Atom|Atomlist]) :-
	atom_codes(Atom,String),
	atomize_strings(Stringlist, Atomlist).

get_triggerlist(UsefulTokenList,NegationPhraseList,TriggerList) :-
	findall(X,
		get_neg_phrase_triggerlist(UsefulTokenList,NegationPhraseList,X),
		TriggerList0),
	flatten(TriggerList0,TriggerList).

get_neg_phrase_triggerlist(RawTokenListIn, NegPhraseList, TriggerList) :-
	member(NegPair, NegPhraseList),
	NegPair = [NegType,NegTerm],
	findall(X, map_negterm_tokens(RawTokenListIn,NegTerm,X), TokenResult),
	make_triggers(TokenResult, NegType, TriggerList).

make_triggers([], _, []).
make_triggers([TokenList|ListOfTokenLists], NegType, [Trigger|TriggerList]) :-
	Trigger = trigger(NegType,TokenList),
	make_triggers(ListOfTokenLists, NegType, TriggerList).

map_negterm_tokens(TokenList, NegTerm, NegTermTokenList) :-
	atomize_strings(NegTermStringList, NegTerm),
	tokenize_strings(NegTermStringList, NegTermTokenList),
	sublist(TokenList, NegTermTokenList).

tokenize_strings([], []).
tokenize_strings([String|StringList], [Token|TokenList]) :-
	Token = tok(_,_,String,_,_),
	tokenize_strings(StringList, TokenList).

% finding negations in a sentence (or utterance?)
%
% | ?- Z = ["the"," ","patient"," ","denies"," ","chest"," ","pain"," ","and"," ","has"," ","no"," ","shortage"," ","of"," ","breath"], atomize_strings(Z,Y), sublist(Y,X), negation_phrase_tokens(nega,X).
%
% Z = ["the"," ","patient"," ","denies"," ","chest"," ","pain"," ","and"," ","has"," ","no"," ","shortage"," ","of"," ","breath"],
% Y = [the,' ',patient,' ',denies,' ',chest,' ',pain,' ',and,' ',has,' ',no,' ',shortage,' ',of,' ',breath],
% X = [no] ;
%
% Z = ["the"," ","patient"," ","denies"," ","chest"," ","pain"," ","and"," ","has"," ","no"," ","shortage"," ","of"," ","breath"],
% Y = [the,' ',patient,' ',denies,' ',chest,' ',pain,' ',and,' ',has,' ',no,' ',shortage,' ',of,' ',breath],
% X = [denies] ;
%
% no
%
check_for_negation_phrase(Target, Type, WordList) :-
	sublist(Target, WordList),
	WordList = [H|T],
	negation_phrase_tokens(Type, H, T).

negation_phrase_tokens(nega, H, T) :-
	nega_phrase_tokens(H, T).
negation_phrase_tokens(negb, H, T) :-
	negb_phrase_tokens(H, T).
negation_phrase_tokens(pnega, H, T) :-
	pnega_phrase_tokens(H, T).
negation_phrase_tokens(pnegb, H, T) :-
	pnegb_phrase_tokens(H, T).
negation_phrase_tokens(pseudoneg, H, T) :-
	pseudoneg_phrase_tokens(H, T).
negation_phrase_tokens(conj, H, T) :-
	conj_phrase_tokens(H, T).

% Getting a list of negations using findall/3
%
% Y = [the,' ',patient,' ',denies,' ',chest,' ',pain,' ',and,' ',has,' ',no,' ',shortage,' ',of,' ',breath], findall(X, check_for_negation_phrase(nega,Y,X),L).
%
% Y = [the,' ',patient,' ',denies,' ',chest,' ',pain,' ',and,' ',has,' ',no,' ',shortage,' ',of,' ',breath],
% X = _7902,
% L = [[no],[denies]] 

get_negation_phrase_list(Target, ResultList) :-
	findall([Type,X],
		check_for_negation_phrase(Target,Type,X),
		ResultList).


% Return list of phrases and their associated candidates--both
% those in the candidates and those in the mappings.
% If both candidates and mappings are being generated,
% this will be dpplicated, hence the sort.
list_phrases_with_candidates([],[]).   
list_phrases_with_candidates([DisambiguatedMMOPhrase|DisambiguatedMMOPhraseList],
			     [PhraseMap|PhraseMaps]) :-
	DisambiguatedMMOPhrase =
	          phrase(PhraseObject,Candidates,Mappings,_PWI,_GVCs,_EV0,_APhrases),
	% PhraseMap = [PhraseObject,Mappings],
	Mappings = mappings(MappingsList),
	get_all_mappings_candidates(MappingsList, AllMappingsCandidates0),
	append(AllMappingsCandidates0, AllMappingsCandidates),
	Candidates = candidates(_,_,_,_,EVList),
	append(AllMappingsCandidates, EVList, AllCandidates0),
	sort(AllCandidates0, AllCandidates),
	PhraseMap = PhraseObject:AllCandidates,
	list_phrases_with_candidates(DisambiguatedMMOPhraseList,PhraseMaps).


get_all_mappings_candidates([], []).
get_all_mappings_candidates([FirstMapping|RestMappings],
			    [FirstMappingsCandidates|RestMappingsCandidates]) :-
	FirstMapping = map(_Score, FirstMappingsCandidates),
	get_all_mappings_candidates(RestMappings, RestMappingsCandidates).

% map concepts of head and verb phrases, ignore the others
keep_useful_phrasemaps(PhraseMaps, FinalPhraseMaps) :-
	delete_phrasemaps_with_empty_candidates(PhraseMaps, FinalPhraseMaps0),
	delete_nonuseful_phrasemaps(FinalPhraseMaps0, FinalPhraseMaps).

mincoman_get_pos_tag([], []).
mincoman_get_pos_tag([MincomanElement|MincomanElements], Tag) :-
	( ( MincomanElement = head(_)
	  ; MincomanElement = verb(_)
	  ; MincomanElement = mod(_) ) ->
	    Tag = MincomanElement
	; mincoman_get_pos_tag(MincomanElements, Tag)
	).

phrase_get_pos_tag(Phrase,Tag) :-
	Phrase = phrase(_LowerPhraseText,Mincoman,_PosPair,_),
	mincoman_get_pos_tag(Mincoman,Tag).

delete_nonuseful_phrasemaps([], []).
delete_nonuseful_phrasemaps([PhraseMap|PhraseMaps], FinalPhraseMaps) :-
	PhraseMap = Phrase:_CandidateList,
	phrase_get_pos_tag(Phrase, Tag),
	( Tag \== [] ->
	  FinalPhraseMaps = [PhraseMap|RestFinalPhraseMaps]
	; FinalPhraseMaps = RestFinalPhraseMaps
	),
	delete_nonuseful_phrasemaps(PhraseMaps, RestFinalPhraseMaps).

delete_phrasemaps_with_empty_candidates([], []).
delete_phrasemaps_with_empty_candidates([PhraseMap|PhraseMaps], FinalPhraseMaps) :-
	PhraseMap = _Phrase:CandidateList,
	% ( Mappings = mappings([]) ->
	( CandidateList = [] ->
	  FinalPhraseMaps = RestFinalPhraseMaps
	; FinalPhraseMaps = [PhraseMap|RestFinalPhraseMaps]
	),
	delete_phrasemaps_with_empty_candidates(PhraseMaps, RestFinalPhraseMaps).

% List concepts that have positions before or after trigger, based on
% type of negation.
%
list_concepts_for_triggers(Triggers,ConceptTokensPhraseMaps,PhraseMaps) :-
	list_concepts_for_triggers_aux(Triggers,ConceptTokensPhraseMaps,PhraseMaps0),
	flatten(PhraseMaps0,PhraseMaps1),
	sort(PhraseMaps1, PhraseMaps).

list_concepts_for_triggers_aux([],_,[]).
list_concepts_for_triggers_aux([Trigger|Triggers],ConceptTokensPhraseMaps,[PhraseMap|PhraseMaps]) :-
	Trigger = trigger(NegationType, TokenList),
	list_concepts_for_one_trigger(NegationType, TokenList, ConceptTokensPhraseMaps, PhraseMap),
	list_concepts_for_triggers_aux(Triggers,ConceptTokensPhraseMaps,PhraseMaps).

before_or_after(nega,      after).
before_or_after(pnega,     after).
before_or_after(pseudoneg, after).
before_or_after(negb,      before).
before_or_after(pnegb,     before).
before_or_after(conj,      after).

list_concepts_for_one_trigger(NegationType, TokenList, ConceptTokensPhraseMaps, PhraseMaps) :-
	before_or_after(NegationType, BeforeOrAfter),	
	list_concepts_for_one_trigger_aux(ConceptTokensPhraseMaps,
					  trigger(NegationType,TokenList),
					  BeforeOrAfter,
					  PhraseMaps0), 
	flatten(PhraseMaps0, PhraseMaps). 

list_concepts_for_one_trigger_aux([], _, _BeforeOrAfter, []).
list_concepts_for_one_trigger_aux([ConceptTokensPhraseMap|ConceptTokensPhraseMaps],
				  Trigger, BeforeOrAfter, PhraseMaps) :-
	get_trigger_position(BeforeOrAfter, Trigger, TriggerPositionTerm),
	get_negation_data(TriggerPositionTerm, ConceptTokensPhraseMap,
			  TriggerPosition, ConceptPosition, Phrase, Mappings),
	( % ConceptPosition > TriggerPosition ->
	  test_relative_position(BeforeOrAfter, ConceptPosition, TriggerPosition) ->
	  make_negation_terms(Trigger, Phrase, Mappings, PhraseMap),
	  PhraseMaps = [PhraseMap|RestPhraseMaps]
	; PhraseMaps = RestPhraseMaps
	),
	list_concepts_for_one_trigger_aux(ConceptTokensPhraseMaps, Trigger,
					  BeforeOrAfter, RestPhraseMaps).

get_trigger_position(BeforeOrAfter, trigger(_,Tokens), TriggerPositionTerm) :-
	get_trigger_token(BeforeOrAfter, Tokens, TriggerToken),
	TriggerToken = tok(_Type,_String,_LSCtring,_Pos,TriggerPositionTerm).

get_trigger_token(before, Tokens, TriggerToken) :-
	Tokens = [TriggerToken|_].
get_trigger_token(after, Tokens, TriggerToken) :-
	% reversed order of args from QP library version!
	last(Tokens, TriggerToken).

test_relative_position(before, ConceptPosition, TriggerPosition) :-
	ConceptPosition =< TriggerPosition.
test_relative_position(after, ConceptPosition, TriggerPosition) :-
	ConceptPosition >= TriggerPosition.

get_negation_data(TriggerPositionTerm, ConceptTokensPhraseMap,
		  TriggerPosition, ConceptPosition, Phrase, Mappings) :-
	TriggerPositionTerm     = pos(TriggerPosition,_TriggerLength),
	ConceptTokensPhraseMap  = [ConceptToken,Phrase,Mappings],
	ConceptToken            = tok(_Type,_String,_LCString,_Pos,ConceptPositionTerm),
	ConceptPositionTerm     = pos(ConceptPosition,_ConceptLength).

make_negation_terms(Trigger, Phrase, CandidateList, NegationTermList) :-
	Trigger = trigger(Type,Tokens),
	Tokens = [FirstToken|_Rest],
	FirstToken = tok(_FType,_FString,_FLCString,
			 pos(TriggerAbsStartPos,_),
			 pos(TriggerStartPos,_)),
	% reversed order of args from QP library version!
	last(Tokens, LastToken),
	LastToken = tok(_LType,_LString,_LLCstring,
			pos(_,TriggerAbsEndPos),
			pos(_,_TriggerEndPos)),
	TriggerLength is TriggerAbsEndPos - TriggerAbsStartPos,
	extract_atoms_from_tokenlist(Tokens, AtomList),
	concat_atom(AtomList, ' ', TriggerPhraseText),
	Phrase = phrase(_PhraseText,_Mincoman,_PhraseStartPos/_PhraseEndPos,_),
	% Mappings = mappings(MapList),
	% Mappings = candidates(_,_,_,_,CandidateList),
	% negationlist_from_maplist(MapList, Type, TriggerPhraseText,
	( CandidateList \== [] ->
	  negationlist_from_evlist(CandidateList, Type, TriggerPhraseText,
				   TriggerStartPos, TriggerLength, NegationTermList0)
	;  negationlist_from_no_evlist(Phrase, Type, TriggerPhraseText,
				      TriggerStartPos, TriggerLength, NegationTermList0)
	),
	flatten(NegationTermList0, NegationTermList).
	
% negationlist_from_maplist([], _, _, _, _, []).
% negationlist_from_maplist([Map|MapList], Type, TriggerPhraseText, TriggerStartPos, TriggerLength,
% 			  [NegationTerm|NegationTermList]) :-
% 	% Map = map(_score,EvList),
% 	Map = candidates(_,_,_,_,EvList),
% 	negationlist_from_evlist(EvList, Type, TriggerPhraseText,
% 				 TriggerStartPos, TriggerLength, NegationTerm),
% 	negationlist_from_maplist(MapList, Type, TriggerPhraseText,
% 				  TriggerStartPos, TriggerLength, NegationTermList).
 
negationlist_from_evlist([], _, _, _, _, []).
negationlist_from_evlist([FirstCandidate|RestCandidates], Type, TriggerPhraseText, TriggerStartPos,
			 TriggerLength, NegationTerms) :-
	get_all_candidate_features([cui,metaterm,semtypes,posinfo],
				   FirstCandidate,
				   [CUI,ConceptName,SemTypes,CandidatePosInfo]),
	% format('SemGroup=~q, CUI=~q, ConceptName=~q, SemTypes=~q~n',
	%        [[fndg,dsyn,sosy,cgab,acab,lbtr,inpo,biof,phsf,menp,mobd,comd,anab,emod,patf],
	%         CUI,ConceptName,SemTypes]),
	% true if set of semantic types for the ev term
	% does not contain any in the negex semantic group set
	% Note: The neop and patf semtypes are not part of the original specification.
	negex_semtypes(NegExSemTypes),
	( disjoint(SemTypes, NegExSemTypes) ->
	  NegationTerms = RestNegationTerms
	; % ConceptPosInfo = [ConceptPosInfo0],
	  orig_negation_template(NegationTerm,
				 Type, TriggerPhraseText, [TriggerStartPos/TriggerLength],
				 ConceptName, CUI, CandidatePosInfo),
	  NegationTerms = [NegationTerm|RestNegationTerms]
	),
	negationlist_from_evlist(RestCandidates, Type, TriggerPhraseText,
				 TriggerStartPos, TriggerLength, RestNegationTerms).

negationlist_from_no_evlist(Phrase, Type, TriggerPhraseText, TriggerStartPos,
			    TriggerLength, [NegationTerm]) :-
	get_meaningful_info(Phrase, MText, MPhrasePosInfo),
	!,
	orig_negation_template(NegationTerm,
			       Type, TriggerPhraseText, [TriggerStartPos/TriggerLength],
			       MText, '', [MPhrasePosInfo]).
negationlist_from_no_evlist(_Phrase, _Type, _TriggerPhraseText, _TriggerStartPos,
			    _TriggerLength, []).


get_meaningful_info(Phrase,MText,MPosInfo) :-
	Phrase = phrase(PhraseText,Mincoman,PhraseStartPos/PhraseEndPos,_),
	get_meaningful_items(Mincoman,InputMatches0),
	InputMatches0 \== [],
	flatten(InputMatches0, InputMatches),
	InputMatches = [First|_],
	atom_chars(First,FirstChar),
	length(FirstChar,FirstLen),
	substring(PhraseText,First,FirstOffset,FirstLen),
	MStartPos is FirstOffset + PhraseStartPos,
	MPosInfo = MStartPos/PhraseEndPos,
	Len is PhraseEndPos - FirstOffset,
	substring(PhraseText,MText,FirstOffset,Len).
	
get_meaningful_items([],[]).
get_meaningful_items([MincomanElement|RestMincoman], [Match|RestMatch]) :-
        ( MincomanElement = head(ElementList)
	; MincomanElement = mod(ElementList)
	; MincomanElement = shapes(ElementList)
	; MincomanElement = not_in_lex(ElementList)
	),
	!,
	get_from_list(inputmatch,ElementList,Match),
	get_meaningful_items(RestMincoman,RestMatch).
get_meaningful_items([_MincomanElement|RestMincoman], Matches) :-
	get_meaningful_items(RestMincoman,Matches).

		   
negex_semtypes(NegExSemTypes) :-
	default_negex_semtypes(DefaultNegExSemTypes),
	( control_value(negex_st_add, NegExSemTypesAdd) ->
	  append(DefaultNegExSemTypes, NegExSemTypesAdd, NegExSemTypes0),
	  sort(NegExSemTypes0, NegExSemTypes1)
	; NegExSemTypes1 = DefaultNegExSemTypes
	),
	( control_value(negex_st_del, NegExSemTypesDel) ->
	  subtract(NegExSemTypes1, NegExSemTypesDel, NegExSemTypes2),
	  sort(NegExSemTypes2, NegExSemTypes3)
	; NegExSemTypes3 = NegExSemTypes1
	),
	( control_value(negex_st_set, NegExSemTypesSet) ->
	  sort(NegExSemTypesSet, NegExSemTypes4)
	; NegExSemTypes4 = NegExSemTypes3
	),
	( intersection(NegExSemTypes4, [all,'ALL'], [_|_]) ->
	  NegExSemTypes = _ALL
	; NegExSemTypes = NegExSemTypes3
	).

default_negex_semtypes([acab,anab,biof,cgab,comd,dsyn,emod,fndg,
			inpo,lbtr,menp,mobd,neop,patf,phsf,sosy]).

% remove negation terms after conjunctions if there are any conjunctions.
remove_negation_terms_after_conjs(NegationTerms,FilteredNegationTerms) :-
	( find_conj_terms(NegationTerms,ConjunctionTerms) ->
	  remove_negation_terms_after_conjs_aux(NegationTerms,ConjunctionTerms,
						FilteredNegationTerms0),
	  flatten(FilteredNegationTerms0, FilteredNegationTerms)
	; FilteredNegationTerms = NegationTerms
	).

remove_negation_terms_after_conjs_aux([] ,_, []).
remove_negation_terms_after_conjs_aux([NegationTerm|NegationTerms], ConjunctionTerms,
 				      FilteredNegationTerms) :-
	( is_negation_term_after_conj(ConjunctionTerms, NegationTerm) ->
	  FilteredNegationTerms = RestFilteredNegationTerms
	; FilteredNegationTerms = [NegationTerm|RestFilteredNegationTerms]
	),
	remove_negation_terms_after_conjs_aux(NegationTerms, ConjunctionTerms,
					      RestFilteredNegationTerms).

% does negation term correspond to one the conjunction negation terms?
is_negation_term_after_conj([ConjunctionTerm|ConjunctionTerms],NegationTerm) :-
	orig_negation_template(ConjunctionTerm,
			       conj, _TriggerPhraseText, [ConjTriggerStartPos/_],
			       _Concept1, _CUI1, ConjConceptPosInfo),
	orig_negation_template(NegationTerm,
			       _Type, _NegationPhraseText, [NegationTriggerStartPos/_],
			       _Concept2, _CUI2, NegationConceptPosInfo),
	% NOTE: ConjPosInfo in conjunction and NegationPosInfo should be
	% exactly the same if they came from the same mapping.
	( ConjTriggerStartPos >= NegationTriggerStartPos,
	  ConjConceptPosInfo  == NegationConceptPosInfo ->
	  true
	; is_negation_term_after_conj(ConjunctionTerms, NegationTerm)
	).

% list the conjunction negation term if they exist
find_conj_terms([], []).
% find_conj_terms_aux([NegationTerm|NegationTerms], [ConjunctionTerm|ConjunctionTerms]) :-
find_conj_terms([NegationTerm|NegationTerms], ConjunctionTerms) :-
	( orig_negation_template(NegationTerm,
				 conj, _ConjTrigger, _ConjTriggerPosInfo,
				 _ConjConcept, _ConjCUI, _ConjConceptPosInfo) ->
	  ConjunctionTerm = NegationTerm,
	  ConjunctionTerms = [ConjunctionTerm|RestConjunctionTerms]
	; ConjunctionTerms = RestConjunctionTerms
	),
	find_conj_terms(NegationTerms, RestConjunctionTerms).

extract_trigger_sequences([], []).
extract_trigger_sequences([Trigger|TriggerList], [Seq|SeqList]) :-
	Trigger = trigger(_, Seq),
	extract_trigger_sequences(TriggerList, SeqList).

% Keep triggers that have an associated token sequence that matches an
% element of the list of unsubsumed token sequences.  
keep_triggers_with_seqs([],_,[]).
keep_triggers_with_seqs([Trigger0|Triggers0], TriggerSeqList, Triggers) :-
	Trigger0 = trigger(_, Seq),
	% is Seq of Trigger0 member of TriggerSeqList?
	( memberchk(Seq, TriggerSeqList) -> 
	  Trigger = Trigger0,
	  Triggers = [Trigger|RestTriggers]
	; Triggers = RestTriggers
	),
	keep_triggers_with_seqs(Triggers0, TriggerSeqList, RestTriggers).

%
% Given 
%   X=[[a],[a,b,c]]
% such that 
%   Y=[[a,b,c]]
% or given
%   X=[[a],[a,b],[a,b,c]]
% such that 
%   Y=[[a,b,c]]
% Given a list of sequences, remove all sequences that are proper
% subsequences of any sequence in the list.

remove_proper_subseqs([], []).
remove_proper_subseqs([Seq|Seqs], Results) :-
	( is_proper_subseq_of_anyseq(Seq,Seqs) ->
	  Results = RestResults
	; Results = [Seq|RestResults]
	),
 	remove_proper_subseqs(Seqs, RestResults).

list_proper_subseq_of_anyseq([],_,[]).
list_proper_subseq_of_anyseq([Seq|Seqs], TargetSeq, [Result|Results]) :-
	( subseq1(Seq, TargetSeq) -> 
	  Result = Seq
	; Result = []
	),
	list_proper_subseq_of_anyseq(Seqs, TargetSeq, Results).

is_proper_subseq_of_anyseq(TargetSeq, Seqs) :-
	list_proper_subseq_of_anyseq(Seqs,TargetSeq,Results0),
	flatten(Results0,Results),
	length(Results,L), 
	L > 0.

%
% if "and" in utterance and
%      a negation phrase precedes the "and" and a negation phrase follows the "and"
% then
%     umls concepts preceding the "and" belong to the negation phrase preceding the and
%     umls concepts following the "and" belong to the negation phrase following the and
% From: 
% NegEx version 2: (https://www.dbmi.pitt.edu/chapman/NegEx.html), III. NegEx Algorithm:, Section A.
%
cull_negterms_eliminated_by_conj_and(TokenList, NegationTerms, FilteredNegationTerms) :-
	( string_find_tokenpos(TokenList, "and", AndPos) ->
	    ( are_negationterms_before_target(NegationTerms,AndPos),
	      are_negationterms_after_target(NegationTerms,AndPos) ->
	      list_negation_pairs_before_target(NegationTerms, AndPos, NegationTerms0),
	      list_negation_pairs_after_target(NegationTerms, AndPos, NegationTerms1),
	      append(NegationTerms0, NegationTerms1, FilteredNegationTerms)
	    ; FilteredNegationTerms = NegationTerms
	    )
	; FilteredNegationTerms = NegationTerms
	).

string_find_tokenpos([Token|TokenList], TermString, TokenPos) :-
	Token = tok(_,_,NString,_,PosLen),
	PosLen = pos(Pos,_),
	( NString == TermString ->
	  TokenPos = Pos
	; string_find_tokenpos(TokenList, TermString, TokenPos)
	).

are_negationterms_before_target([NegationTerm|NegationTermList], TargetPos) :-
	orig_negation_template(NegationTerm,
			       _Type, _TriggerPhraseText, TriggerPosInfo,
			       _Concept, _CUI, _ConceptPosInfo),

	TriggerPosInfo = [TermPos/_|_],
	( TermPos < TargetPos ->
	  true
	; are_negationterms_before_target(NegationTermList, TargetPos)
	).
	
are_negationterms_after_target([NegationTerm|NegationTermList], TargetPos) :-
	orig_negation_template(NegationTerm,
			       _Type, _TriggerText, TriggerPosInfo,
			       _ConceptName, _CUI, _ConceptPosInfo),
	TriggerPosInfo = [TermPos/_|_],
	( TermPos > TargetPos ->
	  true
	; are_negationterms_after_target(NegationTermList, TargetPos)
	).

list_negation_pairs_before_target([], _, []).
list_negation_pairs_before_target([NegationTerm|NegationTermList], TargetPos,
				  FilteredNegationTerms) :-
	orig_negation_template(NegationTerm,
			       _Type, _TriggerText, TriggerPosInfo,
			       _ConceptName, _CUI, ConceptPosInfo),
	% PosInfo can consist of several StartPos/Length terms
	TriggerPosInfo = [TriggerStartPos/_|_],
	ConceptPosInfo = [ConceptStartPos/_|_],
	( TriggerStartPos < TargetPos,
	  ConceptStartPos < TargetPos ->
	  FilteredNegationTerms = [NegationTerm|RestFilteredNegationTerms]
	; FilteredNegationTerms = RestFilteredNegationTerms
	),
	list_negation_pairs_before_target(NegationTermList, TargetPos, RestFilteredNegationTerms).

list_negation_pairs_after_target([], _, []).
list_negation_pairs_after_target([NegationTerm|NegationTermList], TargetPos,
				 FilteredNegationTerms) :-
	orig_negation_template(NegationTerm,
			       _Type, _TriggerText, TriggerPosInfo,
			       _ConceptName, _CUI, ConceptPosInfo),
	% PosInfo can consist of several StartPos/Length terms
	TriggerPosInfo = [TriggerStartPos/_|_],
	ConceptPosInfo = [ConceptStartPos/_|_],
	( TriggerStartPos > TargetPos,
	  ConceptStartPos > TargetPos ->
	  FilteredNegationTerms = [NegationTerm|RestFilteredNegationTerms]
	; FilteredNegationTerms = RestFilteredNegationTerms
	),
	list_negation_pairs_after_target(NegationTermList, TargetPos, RestFilteredNegationTerms).

remove_spurious_negterms([], _, _, _, []).
remove_spurious_negterms([NegationTerm|NegationTermList],
			 UtteranceMaxDist, ConceptMaxDist,
			 TokenList, NegationTermsOut) :- 
	( spurious_negterm(TokenList, UtteranceMaxDist, ConceptMaxDist, NegationTerm) ->
	  NegationTermsOut = RestNegationTermsOut
	; NegationTermsOut = [NegationTerm|RestNegationTermsOut]
	),
	remove_spurious_negterms(NegationTermList,
					   UtteranceMaxDist, ConceptMaxDist,
					   TokenList, RestNegationTermsOut).

spurious_negterm(TokenList, UtteranceMaxDist, ConceptMaxDist, NegationTerm) :-
	orig_negation_template(NegationTerm,
			       _Type, TriggerText, TriggerPosInfo,
			       _ConceptName, _CUI, ConceptPosInfo),
	charpos_to_tokenindex(TokenList, NegationTerm, TriggerPosInfo, 1, TriggerTokenPos),
	charpos_to_tokenindex(TokenList, NegationTerm, ConceptPosInfo, 1, ConceptTokenPos),
	( negterm_outside_window(TokenList, TriggerText,
				 TriggerTokenPos, ConceptTokenPos,
				 UtteranceMaxDist, ConceptMaxDist) ->
	  true
	; intervening_negation_trigger(TokenList, NegationTerm)
	).

% We have decided to modify the window logic as follows:
% (1) If the number of tokens between the end of the negation trigger
%     and the end of the utterance is =< UtteranceMaxDist (currently 20),
%     do not use any window -- i.e., DO NOT rule out the negation;
% (2) Otherwise, use a window size of ConceptMaxDist (currently 10)
%     within which both the negation trigger and the negated concept must be found.

% The logic reduces to this: The negation term is outside the window
% IFF the following two conditions both hold:
% (a) the distance between the trigger and the end of the utterance
%     exceeds UtteranceMaxDist
% (b) the distance between the trigger and the concept
%     exceeds ConceptMaxDist

negterm_outside_window(TokenList, TriggerText,
		       TriggerTokenPos, ConceptTokenPos,
		       UtteranceMaxDist, ConceptMaxDist) :-
	length(TokenList, TokenListLength),
	term_wordlength(TriggerText, WordLength),
	TriggerLastTokenPos is TriggerTokenPos + WordLength - 1,
	TriggerDistanceFromUtteranceEnd is TokenListLength - TriggerLastTokenPos,
	TriggerDistanceFromConcept is abs(ConceptTokenPos - TriggerLastTokenPos),
	TriggerDistanceFromUtteranceEnd > UtteranceMaxDist,
	TriggerDistanceFromConcept > ConceptMaxDist.

intervening_negation_trigger(TokenList, NegationTerm) :-
	orig_negation_template(NegationTerm,
			       _Type, TriggerPhraseText, TriggerPosInfo,
			       _Concept, _CUI, ConceptPosInfo),
	TriggerPosInfo = [FirstTriggerStartPos/_FirstTriggerEndPos|_],
	ConceptPosInfo = [FirstConceptStartPos/_FirstConceptEndPos|_],
	sort([FirstTriggerStartPos, FirstConceptStartPos], [EarlierStartPos, LaterStartPos]),
	extract_negation_tokens(TokenList, EarlierStartPos, LaterStartPos, NegationTokens),
 	extract_atoms_from_tokenlist(NegationTokens, NegationAtomList),
	tokenize_text_utterly(TriggerPhraseText, TriggerPhraseAtomsWithBlanks),
	remove_blank_atoms(TriggerPhraseAtomsWithBlanks, TriggerPhraseAtoms),
	append([_Before, TriggerPhraseAtoms, PhraseAtomsAfterTrigger], NegationAtomList),
	!,
	check_for_negation_phrase(PhraseAtomsAfterTrigger, _Type, _WordList),
	!.

% Extract all the tokens from the TokenList that
% lie between the negation trigger and the negated concept.
extract_negation_tokens([], _EarlierStartPos, _LaterStartPos, []).
extract_negation_tokens([FirstToken|RestTokens],
			EarlierStartPos, LaterStartPos, NegationTokens) :-
	FirstToken = tok(_Type,_String,_NormalizedString,_AbsPosInfo,RelPosInfo),
	RelPosInfo = pos(TokenStartPos, _Length),
	( TokenStartPos < EarlierStartPos ->
	  extract_negation_tokens(RestTokens, EarlierStartPos, LaterStartPos, NegationTokens)
	; TokenStartPos >= EarlierStartPos,
	  TokenStartPos =< LaterStartPos ->
	  NegationTokens = [FirstToken|RestNegationTokens],
	  extract_negation_tokens(RestTokens, EarlierStartPos, LaterStartPos, RestNegationTokens)
	; NegationTokens = []
	).  


remove_blank_atoms([], []).
remove_blank_atoms([H|T], AtomsWithNoBlanks) :-
	( H == ' ' ->
	  remove_blank_atoms(T, AtomsWithNoBlanks)
	; AtomsWithNoBlanks = [H|RestAtomsWithNoBlanks],
	  remove_blank_atoms(T, RestAtomsWithNoBlanks)
	).

% determine number of words in term.
term_wordlength(Term, WordLength) :-
	atom_codes(Term, TermString),
	split_string_completely(TermString, " ", TermList),
	length(TermList, WordLength).

% This error prevents TokenIndex from being returned uninstantiated,
% which should never happen!
%charpos_to_tokenindex([], NegationTerm, CharPosInfo, _, _) :-
%	fatal_error('NegEx negation "~p" beyond char pos ~w.~n~n',
%		    [NegationTerm,CharPosInfo]).
% It happens with SemRep, unfortunately. This does not really address the core issue.
% MetaMap seems to avoid this when it uses term processing option.
charpos_to_tokenindex([], NegationTerm, CharPosInfo, Start, Start).
charpos_to_tokenindex([Token|TokenList], NegationTerm, CharPosInfo, Start, TokenIndex) :-
	Token = tok(_,_,NString,AbsPosInfo,RelPosInfo),
	AbsPosInfo = pos(AbsTokenStart,_),
	RelPosInfo = pos(RelTokenStart,_),
	CharPosInfo = [CharStart/_|_],
	( AbsTokenStart >= CharStart ->
	  TokenIndex = Start
	; RelTokenStart >= CharStart ->
	  TokenIndex = Start
	; set_next(NString, Next, Start) ->
	  charpos_to_tokenindex(TokenList, NegationTerm, CharPosInfo, Next, TokenIndex)
	).

set_next(NString, Next, Start) :-
	( NString == " " ->
	  Next is Start
	; Next is Start + 1
	).

/* Consolidating negation terms:
   Consider the utterance "No abnormality". Generic NegEx will generate
   two negations from this utterance:

   negation(nega,
   	    no, [0/2],
	    ['C0000768':'ABNORMALITY'], [3/12])

   and

   negation(nega,
   	    no, [0/2],
	    ['C1704258':'Abnormality'], [3/12])

   However, there is really only one negation, but the negated concept
   has two mappings. It would be more appropriate to distribute
   the negation trigger over the multiple mappings of the negated concept,
   and have a single negation instead:

   negation(nega,
   	    no,                                                   [37/2],
            ['C0000768':'ABNORMALITY', 'C1704258':'Abnormality'], [81/12])

   This is the purpose of consolidate_negation_terms/2.
   We cannot assume that negations to be consolidated are consecutive
   in the incoming list of negation terms, so the second clause
   cycles through all the other negations (using the backtrackable select/3),
   and if one is found that can be combined, they are combined.

*/

consolidate_negation_terms([], []).
consolidate_negation_terms([H|T], ConsolidatedNegationTerms) :-
	convert_negation_template(H, ConvertedH),
	group_negation_terms(T, ConvertedH, ConsolidatedNegationTerms).

group_negation_terms([], LastNegationTerm, [ConvertedLastNegationTerm]) :-
	convert_negation_template(LastNegationTerm, ConvertedLastNegationTerm).
% FirstNegationTerm has already been converted to the new ConceptCUI list format
group_negation_terms([H|T], FirstNegationTerm, FinalNegationTerms) :-
	select(NegationTerm, [H|T], RestNegationTerms),
	negation_terms_overlap(NegationTerm, FirstNegationTerm),
	!,
	merge_negation_terms(NegationTerm, FirstNegationTerm, ConsolidatedNegationTerm),
	NextNegationTerm = ConsolidatedNegationTerm,
	FinalNegationTerms = RestFinalNegationTerms,
	group_negation_terms(RestNegationTerms, NextNegationTerm, RestFinalNegationTerms).
group_negation_terms([H|T], FirstNegationTerm, FinalNegationTerms) :-
	FinalNegationTerms = [FirstNegationTerm|RestFinalNegationTerms],
	convert_negation_template(H, NextNegationTerm),
	group_negation_terms(T, NextNegationTerm, RestFinalNegationTerms).


convert_negation_template(H, ConvertedH) :-
	( final_negation_template(H,
				  _Type, _TriggerText, _TriggerPosInfo,
				  _ConceptCUIList, _ConceptPosInfo) ->
	  ConvertedH = H
	; orig_negation_template(H,
				 Type, TriggerText, TriggerPosInfo,
				 ConceptName, CUI, ConceptPosInfo),
	  final_negation_template(ConvertedH,
				  Type, TriggerText, TriggerPosInfo,
				  ConceptCUIList, ConceptPosInfo),
	  ConceptCUIList = [CUI:ConceptName]
	).
	
negation_terms_overlap(NegationTerm1, NegationTerm2) :-
	orig_negation_template(NegationTerm1,
			       Type1, TriggerText1, TriggerPosInfo1,
			       _ConceptName1, _CUI1, ConceptPosInfo1),
	final_negation_template(NegationTerm2,
				Type2, TriggerText2, TriggerPosInfo2,
				_ConceptCUIList2, ConceptPosInfo2),
	% Yes this could be done via unification in the head of the clause,
	% but this way the intent is made much clearer.
	Type1 == Type2,
	TriggerText1 == TriggerText2,
	TriggerPosInfo1 == TriggerPosInfo2,
	ConceptPosInfo1 == ConceptPosInfo2.	

merge_negation_terms(NegationTerm1, NegationTerm2, MergedNegationTerm) :-
	orig_negation_template(NegationTerm1,
			       Type, TriggerText, TriggerPosInfo,
			       ConceptName1, CUI1, ConceptPosInfo),
	final_negation_template(NegationTerm2,
				Type, TriggerText, TriggerPosInfo,
				ConceptCUIList2, ConceptPosInfo),
	final_negation_template(MergedNegationTerm,
				Type, TriggerText, TriggerPosInfo,
				[CUI1:ConceptName1|ConceptCUIList2], ConceptPosInfo).

% debug predicate
% print_negterms_distance([], _).
% print_negterms_distance([NegationTerm|NegationTermList], TokenList) :-
% 	negterm_concept_distance(TokenList, NegationTerm, Distance),
% 	format('~q, distance = ~q~n', [NegationTerm,Distance]),
% 	print_negterms_distance(NegationTermList, TokenList).

%
% Fran�ois Lang's tokenlist splitting predicate
%

% No longer needed because NegEx is now called one utterance at a time.
% split_token_list([], []).
% split_token_list([FirstToken|RestTokens], SplitTokenList) :-
% 	FirstToken = tok(FirstTokenType,_,_,_,_),
% 	ignore_token_type(FirstTokenType),
% 	!,
% 	split_token_list(RestTokens, SplitTokenList).
% split_token_list([FirstToken|RestTokens], [FirstUtteranceTokens|RestUtteranceTokens]) :-
% 	FirstToken = tok(sn,_,_,_,_),
% 	!,
% 	FirstUtteranceTokens = [FirstToken|RestFirstUtteranceTokens],
% 	get_utterance_tokens(RestTokens, RestFirstUtteranceTokens, RemainingTokens),
% 	split_token_list(RemainingTokens, RestUtteranceTokens).

% get_utterance_tokens([], [], []).
% get_utterance_tokens([CurrentToken|RestTokens], RestUtteranceTokens, RemainingTokens) :-
% 	CurrentToken = tok(CurrentTokenType,_,_,_,_),
% 	ignore_token_type(CurrentTokenType),
% 	!,
% 	get_utterance_tokens(RestTokens, RestUtteranceTokens, RemainingTokens).
% get_utterance_tokens([CurrentToken|RestTokens], [CurrentToken|RestUtteranceTokens], RemainingTokens) :-
% 	CurrentToken = tok(CurrentTokenType,_,_,_,_),
% 	CurrentTokenType \== sn,
% 	!,
% 	get_utterance_tokens(RestTokens, RestUtteranceTokens, RemainingTokens).
% get_utterance_tokens([CurrentToken|RestTokens], [], [CurrentToken|RestTokens]).


get_first_utterance_tokens([], []).
get_first_utterance_tokens([FirstToken|RestTokens], FirstUtteranceTokens) :-
	FirstToken = tok(FirstTokenType,_,_,_,_),
	ignore_token_type(FirstTokenType),
	!,
	get_first_utterance_tokens(RestTokens, FirstUtteranceTokens).
get_first_utterance_tokens([FirstToken|RestTokens], FirstUtteranceTokens) :-
	FirstToken = tok(sn,_,_,_,_),
	!,
	FirstUtteranceTokens = [FirstToken|RestFirstUtteranceTokens],
	get_rest_utterance_tokens(RestTokens, RestFirstUtteranceTokens).

get_rest_utterance_tokens([], []).
get_rest_utterance_tokens([CurrentToken|RestTokens], RestUtteranceTokens) :-
	CurrentToken = tok(CurrentTokenType,_,_,_,_),
	ignore_token_type(CurrentTokenType),
	!,
	get_rest_utterance_tokens(RestTokens, RestUtteranceTokens).
get_rest_utterance_tokens([CurrentToken|RestTokens], [CurrentToken|RestUtteranceTokens]) :-
	CurrentToken = tok(CurrentTokenType,_,_,_,_),
	CurrentTokenType \== sn,
	!,
	get_rest_utterance_tokens(RestTokens, RestUtteranceTokens).
get_rest_utterance_tokens(_, []).

ignore_token_type(field).
ignore_token_type(label).

% List of negation triggers.
% These are now contained in negex_triggers.pl.

% If show_candidates is on, the candidate terms will be present in the big MMOPhrase term, and
% instantiate_candidates_NegEx_values/2 will instantiate the Negated field in the candidate terms,
% which will instantiate the Negated field in the Mappings because the variables are shared
% in the Candidates and Mappings data structures, so there's nothing to do here.

% If, however, show_candidates is not on, both Evaluations and Evaluations3 will be [],
% so the Negated field in the Mappings will need to be explicitly instantiated here.

% PhraseList is a list of terms of the form
% phrase(phrase(PhraseTextAtom0,Phrase,StartPos/Length,ReplacementPos),
% 	 candidates(Evaluations),
% 	 mappings(Mappings),
% 	 pwi(PhraseWordInfo),
% 	 gvcs(GVCs),
% 	 ev0(Evaluations3),
% 	 aphrases(APhrases))

instantiate_negated_fields([], _NegationTerms).
instantiate_negated_fields([PhraseTerm|RestPhraseTerms], NegationTerms) :-
	instantiate_negated_fields_aux(PhraseTerm, NegationTerms),
	instantiate_negated_fields(RestPhraseTerms, NegationTerms).


instantiate_negated_fields_aux(PhraseTerm, NegationTerms) :-
	PhraseTerm = phrase(phrase(_PhraseTextAtom0,_Phrase,_StartPos/_Length,_ReplacementPos),
			    candidates(_TotalCandidateCount,_ExcludedCandidateCount,
				       _PrunedCandidateCount,_RemainingCandidateCount,
				       Evaluations),
			    mappings(Mappings),
			    pwi(_PhraseWordInfo), gvcs(_GVCs), ev0(Evaluations3),
			    aphrases(_APhrases)),

	instantiate_candidates_NegEx_values(Evaluations,  NegationTerms),
	instantiate_candidates_NegEx_values(Evaluations3, NegationTerms),
	% This needs to be done explicitly if candidates are not displayed
	conditionally_instantiate_mappings_NegEx_values(Mappings, NegationTerms).

conditionally_instantiate_mappings_NegEx_values(Mappings, NegExList) :-
	( \+ control_option(show_candidates) ->
	   (  foreach(map(_NegScore,CandidatesList), Mappings),
	       param(NegExList)
	   do instantiate_candidates_NegEx_values(CandidatesList, NegExList)
	   )
	; true
	).
		
instantiate_candidates_NegEx_values(Evaluations, NegExList) :-
	% format(user_output, '~q~n', [NegExList]),
	(  foreach(Candidate, Evaluations),
	   param(NegExList)
	do % format(user_output, 'BEFORE: ~q~n', [Candidate]),
	   get_all_candidate_features([cui,metaterm,posinfo,negated],
				      Candidate,
				      [CUI,MetaTerm,PosInfo,Negated]),
	   instantiate_negated(CUI, MetaTerm, PosInfo, Negated, NegExList)
	   % format(user_output, 'AFTER:  ~q~n', [Candidate])
	).


instantiate_negated(CUI, MetaTerm, PosInfo, Negated, NegExList) :-
	final_negation_template(Negation,
				Type, _TriggerText, _TriggerPosInfo,
				ConceptCUIList, PosInfo),
	( member(Negation, NegExList),
	  \+ Type == pseudoneg,
	  member(CUI:MetaTerm, ConceptCUIList) ->
	  Negated is 1
	; Negated is 0
	).

% for cui-less items. may need more work. -- Halil 04/09/18
instantiate_negated_fields_nocui([], _NegationTerms,[]).
instantiate_negated_fields_nocui([PhraseTerm|RestPhraseTerms], NegationTerms, [UpdatedPhraseTerm|RestUpdatedPhraseTerms]) :-
	instantiate_negated_fields_nocui_aux(PhraseTerm, NegationTerms, UpdatedPhraseTerm),
	instantiate_negated_fields_nocui(RestPhraseTerms, NegationTerms, RestUpdatedPhraseTerms).

instantiate_negated_fields_nocui_aux(PhraseTerm, NegationTerms, UpdatedPhraseTerm) :-
	PhraseTerm = phrase(phrase(PhraseTextAtom0,Phrase,PhrasePosInfo,ReplacementPos),
			    candidates(TotalCandidateCount,ExcludedCandidateCount,
				       PrunedCandidateCount,RemainingCandidateCount,
				       Evaluations),
			    mappings(Mappings),
			    pwi(PhraseWordInfo), gvcs(GVCs), ev0(Evaluations3),
			    aphrases(APhrases)),
	Evaluations == [],
	Evaluations3 == [],
	Mappings == [],
	% This needs to be done explicitly if candidates are not displayed
	conditionally_instantiate_phrase_NegEx_values(Phrase,PhrasePosInfo,NegationTerms, UpdatedPhrase),
	UpdatedPhraseTerm = phrase(phrase(PhraseTextAtom0,UpdatedPhrase,PhrasePosInfo,ReplacementPos),
			    candidates(TotalCandidateCount,ExcludedCandidateCount,
				       PrunedCandidateCount,RemainingCandidateCount,
				       Evaluations),
			    mappings(Mappings),
			    pwi(PhraseWordInfo), gvcs(GVCs), ev0(Evaluations3),
				   aphrases(APhrases)).
instantiate_negated_fields_nocui_aux(PhraseTerm, _NegationTerms, PhraseTerm).

conditionally_instantiate_phrase_NegEx_values([],_StartPos/_Length,_NegExList,[]) :- !.
conditionally_instantiate_phrase_NegEx_values([MincomanElement|Rest],StartPos/Length,NegExList,[UpdatedMincomanElement|RestOut]) :-
	( MincomanElement = head(ElementList)
	; MincomanElement = mod(ElementList)
	; MincomanElement = shapes(ElementList)
	; MincomanElement = not_in_lex(ElementList)
	),
	!,
	EndPos is StartPos + Length,
	instantiate_negated_nocui(MincomanElement, StartPos, EndPos, NegExList,UpdatedMincomanElement),
	conditionally_instantiate_phrase_NegEx_values(Rest,StartPos/Length,NegExList,RestOut).
conditionally_instantiate_phrase_NegEx_values([MincomanElement|Rest],StartPos/Length,NegExList,[MincomanElement|RestOut]) :-
	conditionally_instantiate_phrase_NegEx_values(Rest,StartPos/Length,NegExList,RestOut).

instantiate_negated_nocui(Element,StartPos,EndPos,NegExList,UpdatedElement) :-
	arg(1,Element,ElementList),
	functor(Element,Name,1),
	get_from_list(inputmatch,ElementList,[InputMatch]),
	( negated_token(InputMatch,StartPos,EndPos,NegExList) ->
	  append(ElementList,[negated(1)], NewElementList)
	; NewElementList = ElementList
	),
	functor(UpdatedElement,Name,1),
	arg(1,UpdatedElement,NewElementList).

negated_token(Token,StartPos,EndPos,[negation(Type,_TriggerText,_TriggerPos,['':Token],[Pos])|_Rest]) :-
	Pos=SPos/EPos,
	SPos >= StartPos,
	EndPos >= EPos,
	\+ Type == pseudoneg,
	!.
negated_token(Token,StartPos,EndPos,[_NegTerm|Rest]) :-
	negated_token(Token,StartPos,EndPos,Rest).
