open MyStd

type month = int
type rank = One | Two | Three | Four
type card' = month * rank
type hikari_t = XHikari
type tanzaku_t = XTanzaku
type tane_t = XTane
type kasu_t = XKasu
type _ card =
  | Hikari_card : card' -> hikari_t card
  | Tanzaku_card : card' -> tanzaku_t card
  | Tane_card : card' -> tane_t card
  | Kasu_card : card' -> kasu_t card
type ecard = CExist : 'a card -> ecard

(* The four of chrysanthemums is *both* a tane and a kasu,
 * but is of type tane card here *)

type tori =
  { hikari : hikari_t card list;
    tanzaku : tanzaku_t card list;
    tane :  tane_t card list; (* 4 of chrys is stored here only *)
    kasu :  kasu_t card list;
    bakehuda : bool }

type yaku =
  | Gokoo | Sikoo | Amesikoo | Sankoo 
  | Akatan | Aotan | Tanzaku of int (* excess # of cards *)
  | Inosikatyoo | Tane of int (* ditto *)
  | Kasu of int (* ditto *)

let aristocrat = Hikari_card (11, Four)

let yaku_of_hikari (cs : hikari_t card list) =
  let l, has_aristo =
    let f (l, has_aristo) c = (l + 1, has_aristo || c = aristocrat) in
    List.fold_left f (0, false) cs in
  if l = 5 then [Gokoo]
  else if l = 4 then
    if has_aristo then [Amesikoo] else [Sikoo]
  else if l = 3 && not has_aristo then [Sankoo]
  else []

let is_ao (Tanzaku_card (m, _)) =
  match m with
  | 6 | 9 | 10 -> true
  | _ -> false

let is_aka (Tanzaku_card (m, _)) = 1 <= m  && m <= 3

let yaku_of_tanzaku (cs : tanzaku_t card list) =
  let l, n_ao, n_aka =
    let f (l, n_ao, n_aka) c =
      (l + 1,
       n_ao + (if is_ao c then 1 else 0),
       n_aka + (if is_aka c then 1 else 0)) in
    List.fold_left f (0, 0, 0) cs in
  (if n_ao >= 3 then [Aotan] else [])
  @ (if n_aka >= 3 then [Akatan] else [])
  @ (if l >= 5 then [Tanzaku (l - 5)] else [])

let ino = Tane_card (7, Four)
let sika = Tane_card (10, Four)
let tyoo = Tane_card (6, Four)
let yaku_of_tane (cs : tane_t card list) =
  let (l, has_ino, has_sika, has_tyoo) = 
    let f (l, has_ino, has_sika, has_tyoo) c =
      (l + 1, has_ino || c = ino, has_sika || c = sika, has_tyoo || c = tyoo) in
    List.fold_left f (0, false, false, false) cs in
  (if has_ino && has_sika && has_tyoo then [Inosikatyoo] else [])
  @ (if l >= 5 then [Tane (l - 5)] else [])

let yaku_of_kasu (cs : kasu_t card list) bakehuda =
  let std = (if bakehuda then 9 else 10) in
  let l = List.length cs in
  if l >= std then  [Kasu (l - std)] else []

let yaku_of_tori t =
  yaku_of_hikari t.hikari
  @ yaku_of_tanzaku t.tanzaku
  @ yaku_of_tane t.tane
  @ yaku_of_kasu t.kasu t.bakehuda


type util = int

(* http://www.geocities.jp/xmbwq497/gihou/koikoirule.html *)
let util_of_yaku = function
  | Gokoo -> 15
  | Sikoo -> 10
  | Amesikoo -> 8
  | Sankoo -> 6
  | Akatan -> 6
  | Aotan -> 6
  | Tanzaku n -> 1 + n
  | Inosikatyoo -> 5
  | Tane n -> 1 + n
  | Kasu n -> 1 + n

let util_of_tori t =
  let f acc c = acc + util_of_yaku c in
  List.fold_left f 0 @@ yaku_of_tori t

let is_month_with_hikari = function
  | 1 | 3 | 8 | 11 | 12 -> true
  | _ -> false

let classify_card c =
  match c with 
  | (m, Four) ->
     if is_month_with_hikari m then CExist (Hikari_card c)
     else CExist (Tane_card c)
  | (m, Three) ->
     begin
       match m with
       | 8 | 11 -> CExist (Tane_card c)
       | 12 -> CExist (Kasu_card c)
       | _ -> CExist (Tanzaku_card c)
     end
  | (m, Two) ->
     if m = 11 then CExist (Tanzaku_card c)
     else CExist (Kasu_card c)
  | (_, One) -> CExist (Kasu_card c)

let cons (c : card') (t : tori) =
  let CExist c = classify_card c in
  match c with
  | Hikari_card _ -> { t with hikari = c::t.hikari }
  | Tane_card _ -> { t with tane = c::t.tane }
  | Tanzaku_card _ -> { t with tanzaku = c::t.tanzaku }
  | Kasu_card _ -> { t with kasu = c::t.kasu }
  

type player = { hand : card' list; tori : tori; koi : tori option }

type player_id = PI | PII

let other = function PI -> PII | PII -> PI

type game' =
  { current : player_id;
    ba : card' list;
    yama : card' list;
    (* sum_hands : int; *)
    pi : player;
    pii : player }
    
type play_t
type koi_t
type awase1_t
type awase2_t
type _ game_phase =
  | Play_phase : play_t game_phase
  | Koi_phase : koi_t game_phase
  | Awase1_phase : card' -> awase1_t game_phase (* lastly played card *)  
  | Awase2_phase : card' -> awase2_t game_phase (* lastly drawn card *)

type 'a game =
  { phase : 'a game_phase;
    data : game' }

let player_of_game' { current = c; pi = pi; pii = pii } =
  match c with
  | PI -> pi
  | PII -> pii
let player_of_game g = player_of_game' g.data

let update_current_player' ({ current = c } as g') p =
  match c with
  | PI -> { g' with pi = p }
  | PII -> { g' with pii = p }
let update_current_player g p =
  { g with data = update_current_player' g.data p }
      
let swap' data = { data with pi = data.pii; pii = data.pi }
let swap g = { g with data = swap' g.data }

type _ move =
  | Play : card' -> play_t move
  | Koi : koi_t move
  | No_koi : koi_t move
  | Awase1 : card' -> awase1_t move
  | Awase1_nop : awase1_t move
  | Awase1_basanbon : card' * card' * card' -> awase1_t move
  | Awase2 : card' * card' -> awase2_t move (* The card drawn comes first *)
  | Awase2_basanbon : card' * card' * card' * card' -> awase2_t move
  | Awase2_nop : card' -> awase2_t move

let awase (m, r) ba =
  let f acc ((m', r') as c') = if m' = m then c' :: acc else acc in 
  List.fold_left f [] ba

let moves : type a. a game -> a move list =
  function
  | { phase = Awase1_phase c; data = data } ->
     begin
       match awase c data.ba with
       | [] -> [Awase1_nop]
       | x::y::z::w::_ -> failwith "moves: too many matching cards"
       | x::y::z::[] -> [Awase1_basanbon (x, y, z)]
       | cs -> List.map (fun c' -> Awase1 c') cs
     end
  | { phase = Awase2_phase c; data = data } -> 
     begin
       match awase c data.ba with
       | [] -> [Awase2_nop c]
       | x::y::z::w::_ -> failwith "moves: too many matching cards"
       | x::y::z::[] -> [Awase2_basanbon (c, x, y, z)]
       | cs -> List.map (fun c' -> Awase2 (c, c')) cs
     end
  | { phase = Koi_phase } -> [Koi; No_koi]
  | { phase = Play_phase } as g ->
     let p = player_of_game g in
     List.map (fun c -> Play c) p.hand

let payoff' g : float option =
  let payoff' { tori = tori } =
    let u = util_of_tori tori in
    if u > 0 then Some (float u) else None in
  let help cur opp =
    match (payoff' cur) with
    | Some po -> Some po
    | None ->
       match payoff' opp with
       | Some po -> Some (~-. po)
       | None -> None in
  match g.current with
  | PI -> help g.pi g.pii
  | PII -> help g.pii g.pi

let payoff {data = g} = payoff' g

type egame = GExist : 'a game -> egame

let apply_awase1_ { phase = Awase1_phase c; data = data } m =
  match data.yama with
  | [] -> failwith "apply : we should never run out of cards"
  | top::yama ->  
     let data = { data with yama = yama } in
     let p = player_of_game' data in
     let help tori cs =
       let p = { p with tori = tori } in
       let data = update_current_player' data p in
       { data with ba = List.diff data.ba cs } in
     begin
       match m with
       | Awase1_nop ->
          { phase = Awase2_phase top;
            data = { data with ba = c::data.ba }}
       | Awase1 c' ->
          let tori = cons c (cons c' p.tori) in
           { phase = Awase2_phase top; data = help tori [c'] }
       | Awase1_basanbon (c', c'', c''') ->
          let tori = cons c (cons c' (cons c'' (cons c''' p.tori))) in
           { phase = Awase2_phase top; data = help tori [c'; c''; c''']}
     end

let apply_awase2 { phase = Awase2_phase c; data = data } m =
  let p = player_of_game' data in
  let help tori cs =
    let p = { p with tori = tori } in
    let data = update_current_player' data p in
    { data with ba = List.diff data.ba cs } in
  let k data =
    let flag = 
      match payoff' data with
      | Some f ->
         assert (f > 0.);
         begin
           match (player_of_game' data).koi with
           | None -> true
           | Some t when f > float (util_of_tori t) -> true (* Is this OK? *)
           | _ -> false
         end
      | _ -> false in
    if flag then GExist { phase = Koi_phase; data = data }
    else GExist { phase = Play_phase; data = swap' data } in
  match m with
  | Awase2_nop _ -> (* need to add it *)
     GExist { phase = Play_phase;
              data = { data with ba = c::data.ba }}
  | Awase2 (_, c') ->
     let tori = cons c (cons c' p.tori) in
     k (help tori [c'])
  | Awase2_basanbon (_, c', c'', c''') ->
     let tori = cons c (cons c' (cons c'' (cons c''' p.tori))) in
     k (help tori [c'; c''; c'''])

let apply_play_ { data = data } (Play c) =
  let p = player_of_game' data in
  let p = { p with hand = List.remove c p.hand } in
  { phase = Awase1_phase c; data = update_current_player' data p }

let apply_koi_ { data = data } = function
  | Koi ->
     let p = player_of_game' data in
     let data = update_current_player' data { p with koi = Some (p.tori) } in
     { phase = Play_phase; data = data }
  | No_koi -> { phase = Play_phase; data = swap' data }

let apply : type a. a game -> a move -> egame
  = fun g m ->
  match g with
  | { phase = Awase1_phase _ } as g -> GExist (apply_awase1_ g m)
  | { phase = Awase2_phase _} as g -> apply_awase2 g m
  | { phase = Play_phase } as g -> GExist (apply_play_ g m)
  | { phase = Koi_phase } as g -> GExist (apply_koi_ g m)

let apply_only_move g =
  let ms = moves g in
  match ms with
  | [m] -> apply g m
  | _ -> failwith "apply_only_move: applied to an invalid list"

let cards_of_tori t =
  let a = List.map (fun (Hikari_card c) -> c) t.hikari in
  let b = List.map (fun (Tane_card c) -> c) t.tane in
  let c = List.map (fun (Tanzaku_card c) -> c) t.tanzaku in
  let d = List.map (fun (Kasu_card c) -> c) t.kasu in
  a @ b @ c @ d 

let hana_karuta : card' list =
  List.flatten
  @@ List.map (fun r ->
         List.map (fun m -> (m, r)) [1;2;3;4;5;6;7;8;9;10;11;12])
              [One;Two;Three;Four]

(* create a random game based on the current player's perspective *)
let random : type a. a game -> a game =
  fun g ->
  let p = player_of_game g in
  let cs_tori = cards_of_tori p.tori in
  let p' = (player_of_game (swap g)) in
  let cs_tori' = cards_of_tori p'.tori in
  let additional =
    match g with
    | { phase = Awase1_phase c } -> [c]
    | { phase = Awase2_phase c } -> [c]
    | _ -> [] in
  let visible = additional @ p.hand @ g.data.ba @ cs_tori @ cs_tori' in
  let cs = List.diff hana_karuta visible in
  let hand = List.take (List.length p'.hand) cs in (* I'm not cheating! *)
  let p' = { p' with hand = hand } in
  swap (update_current_player (swap g) p')

module MCUCB1 (P : sig val param : float val limit : int end) = struct
  let param = P.param
  let limit = P.limit
    
  let rec simple_playout : type a. player_id -> a game -> a move -> float =
    fun p g m ->
    let GExist g = apply g m in
    match payoff g with
    | Some po ->
         if g.data.current = p then po else ~-.po
    | None ->
       let ms = moves g in
       simple_playout p g (Random.randomth_list ms)

  type stat = { mutable sum_payoff : float;  mutable n_trials : int }

  let add_one_playout :
  type a. a game -> a move list -> stat array -> unit =
    fun game ms ts ->
    let { data = { current = p }} = game in
    let tot =
      let f tot { n_trials = n } = tot + n in
      Array.fold_left f 0 ts in
    let (i, _) =
      let rec n = Array.length ts in
      let rec loop i (i_acc,  v_acc) =
        if i >= n then (i_acc, v_acc)
        else
          let { n_trials = n_trials; sum_payoff = sum_payoff } = ts.(i) in
          if n_trials = 0 then
            loop (i + 1) (i, infinity)
          else
            let f_trials = (float_of_int n_trials) in
            let v =
              sum_payoff /. f_trials
              +. param  *. sqrt (log (float_of_int tot) /. f_trials) in
            begin
              (* Printf.printf "%f\n" v; *)
              if v > v_acc then
                loop (i + 1) (i,  v)
              else loop (i + 1) (i_acc,  v_acc)
            end in
      loop 0 (-1, neg_infinity) in
    if i < 0 then
      failwith "add_one_playout: No available moves"
    else
      let po = simple_playout p game (List.nth ms i) in
      ts.(i).sum_payoff <- ts.(i).sum_payoff +. po;
      ts.(i).n_trials <- ts.(i).n_trials + 1

  let good_move : type a. a game -> a move =
    fun g ->
    let ms = moves g in
    match ms with
    | [m] -> m
    | _ ->
       let n = (List.length ms) in
       let ts =
         let f _ = { sum_payoff = 0.; n_trials = 0 } in
         Array.init n f in
       let rec loop i =
         if i >= limit then ()
         else
           let g = random g in
           add_one_playout g ms ts;
           loop (i + 1) in
       loop 0;
       let i =
         let rec loop i (i_acc, po_acc) =
           if i >= n then i_acc
           else
             let s = ts.(i) in
             let po_exp = (s.sum_payoff /. float_of_int s.n_trials) in
             if po_exp > po_acc then loop (i + 1) (i, po_exp)
             else loop (i + 1) (i_acc, po_acc) in
         loop 0 (-1, neg_infinity) in
       if i < 0 then
         failwith "good_move: No available moves???"
       else List.nth ms i
end
