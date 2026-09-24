from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.economy import GameRound, GameRoundStatus
from app.models.economy_stats import UserGameStats
from app.models.game import GameBet, GameDefinition, GameSession
from app.models.user import User
from app.services import (
    economy_service_client,
    event_outbox_service,
    game_service as base,
    game_stats_service,
    global_jungle_game_service as jungle,
)

JUNGLE_HUNT_KEY = jungle.JUNGLE_HUNT_KEY
LEGACY_JUNGLE_KEYS = {"jungle_hunt", "jackpot_king", JUNGLE_HUNT_KEY}


def _json(raw: str | None) -> dict[str, Any]:
    return base._loads(raw, {})


def _save_json(value: dict[str, Any]) -> str:
    return base._dumps(value)


def _map_economy_error(exc: Exception) -> HTTPException:
    if isinstance(exc, economy_service_client.EconomyServiceError):
        return HTTPException(status_code=exc.status_code, detail=exc.detail)
    return HTTPException(status_code=503, detail=str(exc))


def _wallet_balance(user_id: int) -> int:
    try:
        return int(economy_service_client.wallet_snapshot(user_id=user_id).get("coin_balance") or 0)
    except (economy_service_client.EconomyServiceUnavailable, economy_service_client.EconomyServiceError) as exc:
        raise _map_economy_error(exc) from exc


def _definition_rules(definition: GameDefinition) -> dict[str, Any]:
    defaults = jungle.JUNGLE_RULES if definition.game_key == JUNGLE_HUNT_KEY else base.DEFAULT_RULES
    return {**defaults, **_json(definition.rules_json)}


def _definition_risk(definition: GameDefinition) -> dict[str, Any]:
    defaults = jungle.JUNGLE_RISK if definition.game_key == JUNGLE_HUNT_KEY else base.DEFAULT_RISK
    return {**defaults, **_json(definition.risk_config_json)}


def seed_default_games(db: Session, actor: User | None = None) -> GameDefinition:
    definition = jungle.seed_default_games(db, actor)
    event_outbox_service.enqueue_event(db, event_type="game.catalog.seeded.v1", actor_user_id=actor.id if actor else None, payload={"game_key": definition.game_key, "config_version": definition.config_version})
    db.commit()
    return definition


def list_catalog(db: Session, include_disabled: bool = False) -> list[dict[str, Any]]:
    return jungle.list_catalog(db, include_disabled=include_disabled)


def get_definition(db: Session, game_key: str, include_disabled: bool = False) -> GameDefinition:
    return jungle.get_definition(db, game_key, include_disabled=include_disabled)


def _definition_payload(definition: GameDefinition) -> dict[str, Any]:
    return jungle._definition_payload(definition)


def upsert_definition(db: Session, actor: User, game_key: str, payload: dict[str, Any]) -> GameDefinition:
    definition = jungle.upsert_definition(db, actor, game_key, payload)
    event_outbox_service.enqueue_event(db, event_type="game.catalog.updated.v1", actor_user_id=actor.id, payload={"game_key": definition.game_key, "config_version": definition.config_version})
    db.commit()
    return definition


def get_history(db: Session, limit: int = 30) -> dict[str, Any]:
    return jungle.get_history(db, limit=limit)


def open_session(db: Session, *, game_key: str, user: User, request_id: str, room_id: int | None, bridge_version: int) -> dict[str, Any]:
    definition = get_definition(db, game_key)
    existing = db.query(GameSession).filter(GameSession.request_id == request_id).first()
    if existing is not None:
        if existing.user_id != user.id or existing.game_key != definition.game_key:
            raise HTTPException(status_code=409, detail="Game session request_id is already bound to another session")
        return _session_payload(existing)
    row = GameSession(session_id=str(uuid4()), request_id=request_id, user_id=user.id, game_key=definition.game_key, room_id=room_id, bridge_version=bridge_version, status="ACTIVE", metadata_json=_save_json({"config_version": definition.config_version}))
    db.add(row)
    db.flush()
    event_outbox_service.enqueue_event(db, event_type="game.session.opened.v1", actor_user_id=user.id, payload={"session_id": row.session_id, "game_key": row.game_key, "room_id": room_id})
    db.commit(); db.refresh(row)
    return _session_payload(row)


def close_session(db: Session, *, session_id: str, user: User) -> dict[str, Any]:
    row = db.query(GameSession).filter(GameSession.session_id == session_id, GameSession.user_id == user.id).first()
    if row is None: raise HTTPException(status_code=404, detail="Game session not found")
    if row.status != "CLOSED":
        row.status="CLOSED"; row.closed_at=datetime.utcnow()
        event_outbox_service.enqueue_event(db, event_type="game.session.closed.v1", actor_user_id=user.id, payload={"session_id": row.session_id, "game_key": row.game_key})
        db.commit(); db.refresh(row)
    return _session_payload(row)


def _session_payload(row: GameSession) -> dict[str, Any]:
    return {"session_id": row.session_id, "game_key": row.game_key, "room_id": row.room_id, "bridge_version": int(row.bridge_version or 1), "status": row.status}


def create_round(db: Session, game_key: str, user: User, room_id: int | None = None, *, session_id: str | None = None) -> GameRound:
    if session_id:
        session = db.query(GameSession).filter(GameSession.session_id == session_id, GameSession.user_id == user.id, GameSession.status == "ACTIVE").first()
        if session is None: raise HTTPException(status_code=409, detail="Active game session not found")
        definition = get_definition(db, game_key)
        if session.game_key != definition.game_key: raise HTTPException(status_code=409, detail="Game session belongs to another game")
    round_obj = jungle.create_round(db, game_key, user, room_id)
    metadata=_json(round_obj.metadata_json)
    if session_id and metadata.get("session_id") != session_id:
        metadata["session_id"]=session_id; round_obj.metadata_json=_save_json(metadata); db.commit(); db.refresh(round_obj)
    event_outbox_service.enqueue_event(db, event_type="game.round.opened.v1", actor_user_id=user.id, payload={"round_id": round_obj.id, "game_key": round_obj.game_key, "session_id": session_id})
    db.commit()
    return round_obj


def get_round_payload(db: Session, round_id: int, user: User | None = None) -> dict[str, Any]:
    return jungle.get_round_payload(db, round_id, user)


def _risk(db: Session, *, user_id: int, game_id: str, amount: int, risk: dict[str, Any]) -> dict[str, Any]:
    if risk.get("testing_mode_enabled") is True or risk.get("enabled") is False:
        return {"level":"LOW","score":0,"action":"ALLOW","probability_mode":"NORMAL","reasons":[]}
    since=datetime.utcnow()-timedelta(hours=24); recent=datetime.utcnow()-timedelta(minutes=5)
    daily_volume=int(db.query(func.coalesce(func.sum(GameBet.accepted_amount),0)).filter(GameBet.user_id==user_id,GameBet.created_at>=since).scalar() or 0)
    recent_count=db.query(GameBet).filter(GameBet.user_id==user_id,GameBet.created_at>=recent,GameBet.accepted_amount>0).count()
    stats=db.query(UserGameStats).filter(UserGameStats.user_id==user_id,UserGameStats.game_id==game_id).first()
    daily_loss=int(stats.daily_loss_amount or 0) if stats else 0
    score=0; reasons=[]
    if amount>=int(risk.get("whale_single_bet",500_000)): score+=35; reasons.append("large_single_bet")
    if daily_volume+amount>int(risk.get("whale_daily_volume",4_000_000)): score+=35; reasons.append("whale_daily_volume")
    if daily_volume+amount>int(risk.get("max_daily_bet_volume",6_000_000)): score+=55; reasons.append("daily_volume_limit")
    if daily_loss>int(risk.get("max_daily_loss",1_500_000)): score+=45; reasons.append("daily_loss_limit")
    if recent_count>=int(risk.get("whale_recent_bet_count",8)): score+=35; reasons.append("high_velocity")
    if score>=int(risk.get("block_score",95)): mode="VERY_LOW_WHALE"; level="WHALE_BLOCK_TIER"
    elif score>=int(risk.get("manual_review_score",70)): mode="LOW_WHALE"; level="WHALE_HIGH_TIER"
    elif score>=35: mode="MEDIUM_WHALE"; level="WHALE_MEDIUM_TIER"
    else: mode="NORMAL"; level="LOW"
    return {"level":level,"score":score,"action":"ALLOW_WHALE_PROBABILITY_REDUCED" if mode!="NORMAL" else "ALLOW","probability_mode":mode,"reasons":reasons}


def _reject(db: Session, round_obj: GameRound, user: User, target_id: int, amount: int, action: str, message: str, extra: dict[str, Any] | None = None) -> dict[str, Any]:
    base.audit(db,round_obj.game_key,round_obj.id,user.id,"BET_REJECTED","HIGH",0,action,message,{"requested_amount":amount,"target_id":target_id,**(extra or {})},user.id); db.commit()
    return {"bet_id":None,"round_id":round_obj.id,"target_id":target_id,"requested_amount":amount,"accepted_amount":0,"spent_coins":0,"reward_coins":0,"net_win_coins":0,"wallet_coin_balance":_wallet_balance(user.id),"winner_coin_balance":None,"risk_level":"HIGH","risk_score":0,"risk_action":action,"message":message}


def place_bet(db: Session, round_id: int, user: User, target_id: int, amount: int, *, request_id: str | None = None) -> dict[str, Any]:
    rid=(request_id or str(uuid4())).strip()
    existing=db.query(GameBet).filter(GameBet.request_id==rid).first()
    if existing is not None:
        if existing.round_id!=round_id or existing.user_id!=user.id or int(existing.target_id)!=int(target_id) or int(existing.amount)!=int(amount):
            raise HTTPException(status_code=409,detail="Bet request_id is already bound to another bet")
        meta=_json(existing.metadata_json); stored=meta.get("result")
        if isinstance(stored,dict): return stored
        if meta.get("financial_status")=="REJECTED": raise HTTPException(status_code=int(meta.get("error_status") or 400),detail=str(meta.get("error_detail") or "Bet rejected"))
        bet=existing
        round_obj=db.query(GameRound).filter(GameRound.id==round_id).first()
        if round_obj is None: raise HTTPException(status_code=404,detail="Game round not found")
        risk_meta=meta.get("risk") or {}
        definition=get_definition(db,round_obj.game_key)
        rules=_definition_rules(definition)
    else:
        round_obj=db.query(GameRound).filter(GameRound.id==round_id).first()
        if round_obj is None: raise HTTPException(status_code=404,detail="Game round not found")
        definition=get_definition(db,round_obj.game_key); rules=_definition_rules(definition); risk=_definition_risk(definition)
        phase=base._phase_metadata(round_obj,rules)
        if phase["phase"]!="BETTING": return _reject(db,round_obj,user,target_id,amount,"BETTING_CLOSED","Betting is closed for this round",phase)
        if int(phase.get("betting_seconds_left",0))<=int(rules.get("close_betting_last_seconds",2)): return _reject(db,round_obj,user,target_id,amount,"LAST_SECONDS_LOCKED","Betting is locked in the last seconds",phase)
        targets=rules.get("targets") or (jungle.JUNGLE_TARGETS if round_obj.game_key==JUNGLE_HUNT_KEY else base.DEFAULT_TARGETS)
        target_map={int(item["id"]):item for item in targets}
        if target_id not in target_map: raise HTTPException(status_code=400,detail="Invalid game target")
        allowed={int(v) for v in rules.get("allowed_bets",base.DEFAULT_RULES["allowed_bets"])}
        if amount not in allowed: return _reject(db,round_obj,user,target_id,amount,"INVALID_BET_AMOUNT","Use one of the allowed bet chips",{"allowed_bets":sorted(allowed)})
        distinct={row[0] for row in db.query(GameBet.target_id).filter(GameBet.round_id==round_id,GameBet.user_id==user.id,GameBet.accepted_amount>0).distinct().all()}
        if target_id not in distinct and len(distinct)>=int(rules.get("max_targets_per_user_round",6)): return _reject(db,round_obj,user,target_id,amount,"TARGET_LIMIT_REACHED","You can bid on only the configured number of items per round")
        existing_total=int(db.query(func.coalesce(func.sum(GameBet.accepted_amount),0)).filter(GameBet.round_id==round_id,GameBet.user_id==user.id).scalar() or 0)
        if existing_total+amount>int(rules.get("max_total_bet_per_round",6_000_000)): return _reject(db,round_obj,user,target_id,amount,"ROUND_USER_LIMIT","Round bet limit reached")
        risk_meta=_risk(db,user_id=user.id,game_id=round_obj.game_key,amount=amount,risk=risk)
        multiplier=int(target_map[target_id].get("multiplier",1)); target_after=int(db.query(func.coalesce(func.sum(GameBet.accepted_amount),0)).filter(GameBet.round_id==round_id,GameBet.target_id==target_id).scalar() or 0)+amount
        totals=dict(db.query(GameBet.target_id,func.coalesce(func.sum(GameBet.accepted_amount),0)).filter(GameBet.round_id==round_id).group_by(GameBet.target_id).all()); totals[target_id]=target_after
        worst=max([int(totals.get(int(item["id"]),0))*int(item.get("multiplier",1)) for item in targets] or [0]); target_liability=target_after*multiplier
        if target_liability>int(rules.get("max_target_liability",45_000_000)) or worst>int(rules.get("max_round_liability",60_000_000)):
            return _reject(db,round_obj,user,target_id,amount,"HIGH_LIABILITY_REJECTED","Bet not accepted because liability is too high",{"target_liability":target_liability,"worst_liability":worst})
        meta={"financial_status":"PENDING","risk":risk_meta,"probability_mode":risk_meta.get("probability_mode","NORMAL"),"request_id":rid}
        bet=GameBet(request_id=rid,round_id=round_id,user_id=user.id,target_id=target_id,amount=amount,accepted_amount=0,risk_level=str(risk_meta.get("level") or "LOW"),risk_score=int(risk_meta.get("score") or 0),risk_action=str(risk_meta.get("action") or "ALLOW"),metadata_json=_save_json(meta))
        db.add(bet); db.commit(); db.refresh(bet)
        definition=get_definition(db,round_obj.game_key); rules=_definition_rules(definition)
    try:
        wallet=economy_service_client.game_wager(user_id=user.id,game_id=round_obj.game_key,round_id=str(round_id),wager_amount=amount,business_reference=f"game-bet:{round_id}:{user.id}:{rid}",metadata={"target_id":target_id,"game_bet_request_id":rid})
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503,detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        meta=_json(bet.metadata_json); meta.update({"financial_status":"REJECTED","error_status":exc.status_code,"error_detail":exc.detail}); bet.metadata_json=_save_json(meta); db.commit()
        raise HTTPException(status_code=exc.status_code,detail=exc.detail) from exc
    if int(bet.accepted_amount or 0)<=0:
        bet.accepted_amount=amount; round_obj.round_pool_amount+=amount
        fee=amount*int(rules.get("platform_fee_basis_points",500))//10_000; round_obj.platform_fee_amount+=fee; round_obj.reward_pool_amount+=max(amount-fee,0)
        game_stats_service.record_game_bet(db,user_id=user.id,game_id=round_obj.game_key,amount=amount)
        base.audit(db,round_obj.game_key,round_id,user.id,"BET_ACCEPTED",bet.risk_level,bet.risk_score,bet.risk_action,"Bet accepted through Economy authority",{"amount":amount,"target_id":target_id,"request_id":rid},user.id)
    result={"bet_id":bet.id,"round_id":round_id,"target_id":target_id,"requested_amount":amount,"accepted_amount":amount,"spent_coins":amount,"reward_coins":0,"net_win_coins":-amount,"wallet_coin_balance":int(wallet.get("coin_balance") or 0),"winner_coin_balance":None,"risk_level":bet.risk_level,"risk_score":bet.risk_score,"risk_action":bet.risk_action,"message":"Bet accepted"}
    meta=_json(bet.metadata_json); meta.update({"financial_status":"COMPLETED","economy_transaction_id":wallet.get("transaction_id"),"result":result}); bet.metadata_json=_save_json(meta)
    event_outbox_service.enqueue_event(db,event_type="game.bet.accepted.v1",actor_user_id=user.id,payload={"bet_id":bet.id,"round_id":round_id,"game_key":round_obj.game_key,"amount":amount,"request_id":rid,"economy_transaction_id":wallet.get("transaction_id")})
    db.commit(); return result


def _generic_payout(user_bets: list[GameBet], winning_target_id: int, targets: list[dict[str,Any]]) -> tuple[int,int]:
    target=next((item for item in targets if int(item["id"])==winning_target_id),{"multiplier":1}); multiplier=int(target.get("multiplier",1)); payout=sum(int(b.accepted_amount or 0)*multiplier for b in user_bets if int(b.target_id)==winning_target_id); return payout,multiplier


def _top_winners(db: Session, settlements: dict[str,Any]) -> list[dict[str,Any]]:
    rows=[]
    for key,value in settlements.items():
        if not isinstance(value,dict): continue
        reward=int(value.get("reward_coins") or 0)
        if reward<=0: continue
        uid=int(key); usr=db.query(User).filter(User.id==uid).first(); name=getattr(usr,"display_name",None) or getattr(usr,"username",None) or f"User {uid}"
        rows.append({"user_id":uid,"name":name,"avatar":(name[:1] or "U").upper(),"coins":reward})
    return sorted(rows,key=lambda x:x["coins"],reverse=True)[:3]


def settle_round(db: Session, round_id: int, user: User) -> dict[str, Any]:
    round_obj=db.query(GameRound).filter(GameRound.id==round_id).first()
    if round_obj is None: raise HTTPException(status_code=404,detail="Game round not found")
    if round_obj.status==GameRoundStatus.CANCELLED.value:
        return {"round_id":round_id,"game_key":round_obj.game_key,"status":round_obj.status,"winning_target_id":0,"multiplier":0,"total_user_bet":0,"total_user_winnings":0,"spent_coins":0,"reward_coins":0,"net_win_coins":0,"wallet_coin_balance":_wallet_balance(user.id),"winner_coin_balance":None,"risk_level":"LOW","risk_score":0,"risk_action":"ROUND_CANCELLED","audit_message":"Round was cancelled.","top_winners":[]}
    definition=get_definition(db,round_obj.game_key); rules=_definition_rules(definition); metadata=_json(round_obj.metadata_json)
    winning=metadata.get("winning_target_id")
    if winning is None:
        if round_obj.game_key==JUNGLE_HUNT_KEY: winning=int(jungle._choose_outcome(db,round_obj))
        else: winning=int(base._choose_winner(round_obj,rules.get("targets") or base.DEFAULT_TARGETS))
        metadata.update({"winning_target_id":winning,"settlement_status":"PENDING","economy_settlements":{}}); round_obj.metadata_json=_save_json(metadata); db.commit()
    winning=int(winning); settlements=metadata.get("economy_settlements") if isinstance(metadata.get("economy_settlements"),dict) else {}
    user_ids=[int(r[0]) for r in db.query(GameBet.user_id).filter(GameBet.round_id==round_id,GameBet.accepted_amount>0).distinct().all()]
    targets=rules.get("targets") or (jungle.JUNGLE_TARGETS if round_obj.game_key==JUNGLE_HUNT_KEY else base.DEFAULT_TARGETS)
    for uid in user_ids:
        key=str(uid); existing=settlements.get(key)
        if isinstance(existing,dict) and existing.get("status")=="COMPLETED": continue
        bets=db.query(GameBet).filter(GameBet.round_id==round_id,GameBet.user_id==uid,GameBet.accepted_amount>0).all(); spent=sum(int(b.accepted_amount or 0) for b in bets)
        if round_obj.game_key==JUNGLE_HUNT_KEY:
            raw_reward=int(jungle._payout_for_user_bets(bets,winning)); stat_multiplier=max([int(jungle._target_by_id(t)["multiplier"]) for t in jungle._basket_target_ids(winning)] or [0])
        else: raw_reward,stat_multiplier=_generic_payout(bets,winning,targets)
        try:
            econ=economy_service_client.game_settle(user_id=uid,game_id=round_obj.game_key,round_id=str(round_id),wager_amount=0,win_amount=raw_reward,multiplier=stat_multiplier,business_reference=f"game-round-settle:{round_id}:{uid}",metadata={"winning_target_id":winning,"raw_reward":raw_reward})
        except economy_service_client.EconomyServiceUnavailable as exc: raise HTTPException(status_code=503,detail=str(exc)) from exc
        except economy_service_client.EconomyServiceError as exc: raise HTTPException(status_code=exc.status_code,detail=exc.detail) from exc
        actual=int(econ.get("win_amount") or 0); game_stats_service.record_game_settlement(db,user_id=uid,game_id=round_obj.game_key,spent_coins=spent,reward_coins=actual,multiplier=stat_multiplier)
        settlements[key]={"status":"COMPLETED","spent_coins":spent,"reward_coins":actual,"wallet_coin_balance":int(econ.get("wallet_coin_balance") or 0),"economy_transaction_id":econ.get("transaction_id")}
        metadata["economy_settlements"]=settlements; round_obj.metadata_json=_save_json(metadata); db.commit()
    top=_top_winners(db,settlements); metadata.update({"economy_settlements":settlements,"top_winners":top,"settlement_status":"COMPLETED","payouts_done":True}); round_obj.metadata_json=_save_json(metadata); round_obj.status=GameRoundStatus.COMPLETED.value; round_obj.ended_at=datetime.utcnow()
    base.audit(db,round_obj.game_key,round_id,user.id,"GLOBAL_ROUND_SETTLED","LOW",0,"AUDIT","Round settled through Economy authority",{"winning_target_id":winning,"top_winners":top},user.id)
    event_outbox_service.enqueue_event(db,event_type="game.round.settled.v1",actor_user_id=user.id,payload={"round_id":round_id,"game_key":round_obj.game_key,"winning_target_id":winning})
    db.commit()
    caller=settlements.get(str(user.id)) if isinstance(settlements.get(str(user.id)),dict) else None; caller_bets=db.query(GameBet).filter(GameBet.round_id==round_id,GameBet.user_id==user.id,GameBet.accepted_amount>0).all(); spent=sum(int(b.accepted_amount or 0) for b in caller_bets); reward=int(caller.get("reward_coins") or 0) if caller else 0; wallet_balance=int(caller.get("wallet_coin_balance") or 0) if caller else _wallet_balance(user.id)
    top_multiplier=int(jungle._target_by_id(winning)["multiplier"]) if round_obj.game_key==JUNGLE_HUNT_KEY else int(next((x.get("multiplier",1) for x in targets if int(x["id"])==winning),1))
    return {"round_id":round_id,"game_key":round_obj.game_key,"status":GameRoundStatus.COMPLETED.value,"winning_target_id":winning,"multiplier":top_multiplier,"total_user_bet":spent,"total_user_winnings":reward,"spent_coins":spent,"reward_coins":reward,"net_win_coins":reward-spent,"wallet_coin_balance":wallet_balance,"winner_coin_balance":wallet_balance if reward>0 else None,"risk_level":"LOW","risk_score":0,"risk_action":"AUDIT","audit_message":"Game Platform chose the outcome; Economy finalized wallet value.","top_winners":top}
