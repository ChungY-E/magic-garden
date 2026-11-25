-- Run once on a new Supabase project, then run seed.sql.
create table public.questions(id int primary key, topic int not null check(topic between 0 and 10), kind text not null, prompt text not null, choices jsonb not null, explanation text not null, asset_paths jsonb not null default '[]');
create table public.rooms(id uuid primary key default gen_random_uuid(), code text unique not null, teacher_hash text not null, topics int[] not null, duration int not null check(duration in (60,120,180)), bonus boolean not null, auto_blind boolean not null, manual_blind boolean not null default false, state text not null default 'waiting', created_at timestamptz not null default clock_timestamp(), starts_at timestamptz, ends_at timestamptz, sun_until timestamptz);
create table public.players(id uuid primary key default gen_random_uuid(), room_id uuid not null references public.rooms on delete cascade, nickname text not null, plant int not null check(plant between 0 and 7), token_hash text not null, energy int not null default 0, correct int not null default 0, bonus int not null default 0, attempts int not null default 0, joined_at timestamptz not null default clock_timestamp(), question_id int references public.questions, issue uuid, ordering int[], seen int[] not null default '{}', locked_until timestamptz, unique(room_id,nickname));
create table public.answers(id bigint generated always as identity primary key, room_id uuid not null references public.rooms on delete cascade, player_id uuid not null references public.players on delete cascade, issue uuid unique not null, question_id int not null references public.questions, correct boolean not null, energy int not null, bonus int not null, created_at timestamptz not null default clock_timestamp());
-- Realtime invalidation only: no names, scores, answers or tokens in this table.
create table public.room_signals(id uuid primary key references public.rooms on delete cascade, revision bigint not null default 0);
create table public.room_status_signals(id uuid primary key references public.rooms on delete cascade, revision bigint not null default 0);
alter table public.room_status_signals enable row level security;
revoke all on public.room_status_signals from anon,authenticated;
grant select on public.room_status_signals to anon,authenticated;
create policy status_signal_read on public.room_status_signals for select to anon,authenticated using (true);
alter publication supabase_realtime add table public.room_status_signals;
alter table public.questions enable row level security;
alter table public.rooms enable row level security;
alter table public.players enable row level security;
alter table public.answers enable row level security;
alter table public.room_signals enable row level security;
revoke all on public.questions,public.rooms,public.players,public.answers,public.room_signals from anon, authenticated;
grant select on public.room_signals to anon,authenticated;
create policy signal_read on public.room_signals for select to anon,authenticated using (true);
alter publication supabase_realtime add table public.room_signals;
create function public.mg_hash(t text) returns text language sql immutable set search_path=pg_catalog as $$ select encode(sha256(convert_to(t,'UTF8')),'hex') $$;
create function public.mg_stage(n int) returns int language sql immutable set search_path=pg_catalog as $$select case when n>=30 then 4 when n>=20 then 3 when n>=10 then 2 when n>=5 then 1 else 0 end$$;
create function public.mg_issue(pid uuid, selected int[]) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare p players%rowtype; q questions%rowtype; qid int; ord int[]; n int; opts jsonb; begin
 select * into p from players where id=pid for update;
 if p.issue is null then
  select id into qid from questions where topic=any(selected) and not(id=any(p.seen)) and id is distinct from p.question_id order by random() limit 1;
  if qid is null then
   p.seen:='{}';
   select id into qid from questions where topic=any(selected) and id is distinct from p.question_id order by random() limit 1;
  end if;
  select * into q from questions where id=qid;
  n:=jsonb_array_length(q.choices);
  select array_agg(x order by random()) into ord from generate_series(0,n-1) x;
  if q.kind='ox' then select array_agg(x order by case when q.choices->>x='O' then 0 else 1 end) into ord from generate_series(0,n-1) x; end if;
  update players set question_id=qid,issue=gen_random_uuid(),ordering=ord,seen=array_append(p.seen,qid) where id=pid returning * into p;
 else select * into q from questions where id=p.question_id; end if;
 -- Image choices contain only asset IDs, not text labels. Asset ID is independent of correct choice.
 select jsonb_agg(case when q.kind='image' then jsonb_build_object('image', q.asset_paths->>x) else jsonb_build_object('text',q.choices->>x) end order by pos) into opts from unnest(p.ordering) with ordinality u(x,pos);
 return jsonb_build_object('issue',p.issue,'topic',q.topic,'kind',q.kind,'prompt',q.prompt,'options',opts,'image',case when q.kind='picture' then q.asset_paths->>0 end);
end $$;
create function public.magic_game(action text, args jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare r rooms%rowtype; p players%rowtype; q questions%rowtype; tok text; code0 text; nick text; chosen int[]; is_teacher boolean:=false; is_student boolean:=false; changed boolean:=false; now0 timestamptz; blind boolean; n int; rank0 numeric; percentile numeric; reward int:=0; extra int:=0; correct0 boolean; choice0 int; result jsonb; question0 jsonb; leaders jsonb; stats jsonb; events jsonb; me jsonb; feedback jsonb; attempt int; existing int;
begin
 if action='server_time' then return jsonb_build_object('server_time',clock_timestamp()); end if;
 if action='create_room' then
  select array_agg(distinct value::int) into chosen from jsonb_array_elements_text(args->'topics');
  if chosen is null or exists(select 1 from unnest(chosen) t where t not between 0 and 10) or (select count(*) from questions where topic=any(chosen))<10 then raise exception '문제를 10개 이상 선택하세요.'; end if;
  if coalesce((args->>'duration')::int,0) not in (60,120,180) then raise exception '게임 시간이 올바르지 않습니다.'; end if;
  tok:=gen_random_uuid()::text||gen_random_uuid()::text;
  -- Serialize code allocation. Expired rows are cleaned up on new room creation.
  perform pg_advisory_xact_lock(741392);
  delete from rooms where created_at < clock_timestamp()-interval '24 hours';
  for attempt in 1..50 loop
   code0:=lpad(floor(random()*10000)::int::text,4,'0');
   exit when not exists(select 1 from rooms where code=code0);
  end loop;
  insert into rooms(code,teacher_hash,topics,duration,bonus,auto_blind) values(code0,mg_hash(tok),chosen,(args->>'duration')::int,coalesce((args->>'bonus')::boolean,true),coalesce((args->>'blind')::boolean,true)) returning * into r;
  insert into room_signals(id) values(r.id);
  insert into room_status_signals(id) values(r.id);
  return jsonb_build_object('id',r.id,'code',r.code,'token',tok);
 end if;
 if action='join_room' then select * into r from rooms where code=args->>'code' for update;
 else select * into r from rooms where id=(args->>'room')::uuid for update; end if;
 if not found then raise exception '방이 없거나 삭제되었습니다.'; end if;
 now0:=clock_timestamp();
 if action='join_room' then
  if r.state='ended' or (r.ends_at is not null and now0>=r.ends_at) then raise exception '종료된 게임입니다.'; end if;
  nick:=btrim(coalesce(args->>'nickname',''));
  if char_length(nick) not between 1 and 10 then raise exception '별명은 1~10자로 입력하세요.'; end if;
  if (select count(*) from players where room_id=r.id)>=30 then raise exception '방이 가득 찼습니다.'; end if;
  if exists(select 1 from players where room_id=r.id and nickname=nick) then raise exception '이미 사용 중인 별명입니다.'; end if;
  if coalesce((args->>'plant')::int,-1) not between 0 and 7 then raise exception '식물을 선택하세요.'; end if;
  tok:=gen_random_uuid()::text||gen_random_uuid()::text;
  insert into players(room_id,nickname,plant,token_hash) values(r.id,nick,(args->>'plant')::int,mg_hash(tok)) returning * into p;
  update room_signals set revision=revision+1 where id=r.id;
  return jsonb_build_object('id',r.id,'code',r.code,'token',tok,'player',p.id);
 end if;
 is_teacher:=coalesce(r.teacher_hash=mg_hash(args->>'token'),false);
 if not is_teacher then
  select * into p from players where room_id=r.id and token_hash=mg_hash(args->>'token');
  is_student:=found;
 end if;
 if not is_teacher and not is_student then raise exception '인증 정보가 올바르지 않습니다.'; end if;
 if r.state='running' and now0>=r.ends_at then update rooms set state='ended' where id=r.id returning * into r; changed:=true; end if;
 if action in ('start_game','end_game','set_sunshine','set_blind','delete_room') and not is_teacher then raise exception '교사 권한이 필요합니다.'; end if;
 if action in ('leave_room','next_question','submit_answer') and not is_student then raise exception '학생 권한이 필요합니다.'; end if;
 case action
 when 'start_game' then
  if r.state<>'waiting' or not exists(select 1 from players where room_id=r.id) then raise exception '시작할 수 없습니다.'; end if;
  update rooms set state='running',starts_at=now0,ends_at=now0+make_interval(secs=>r.duration) where id=r.id returning * into r; changed:=true;
 when 'end_game' then
  if r.state='running' then update rooms set state='ended',ends_at=least(ends_at,now0) where id=r.id returning * into r; changed:=true; end if;
 when 'set_sunshine' then
  if r.state='running' and r.sun_until is null then update rooms set sun_until=least(ends_at,now0+interval '20 seconds') where id=r.id returning * into r; changed:=true; end if;
 when 'set_blind' then
  if r.state='running' then update rooms set manual_blind=not manual_blind where id=r.id returning * into r; changed:=true; end if;
 when 'delete_room' then delete from rooms where id=r.id; return jsonb_build_object('deleted',true);
 when 'leave_room' then
  if r.state<>'waiting' then raise exception '대기 중에만 나갈 수 있습니다.'; end if;
  delete from players where id=p.id; update room_signals set revision=revision+1 where id=r.id; return jsonb_build_object('left',true);
 when 'submit_answer' then
  if r.state<>'running' then raise exception '게임이 종료되었습니다.'; end if;
  if p.locked_until is not null and now0<p.locked_until then raise exception '잠시 후 다시 답하세요.'; end if;
  if p.issue is null or p.issue is distinct from (args->>'issue')::uuid then raise exception '이미 처리되었거나 유효하지 않은 문제입니다.'; end if;
  choice0:=(args->>'choice')::int;
  if choice0 is null or choice0<0 or choice0>=cardinality(p.ordering) then raise exception '보기 번호가 올바르지 않습니다.'; end if;
  select * into q from questions where id=p.question_id;
  correct0:=p.ordering[choice0+1]=0;
  if correct0 then
   reward:=case when r.sun_until>now0 then 2 else 1 end;
   if r.bonus then
    select count(*), count(*) filter(where energy>p.energy)+(count(*) filter(where energy=p.energy)+1)/2.0 into n,rank0 from players where room_id=r.id;
    percentile:=(rank0-0.5)/n;
    if random() < (case when percentile<1.0/3 then 0.1 when percentile<2.0/3 then 0.2 else 0.3 end) then extra:=1+floor(random()*3)::int; end if;
   end if;
  end if;
  insert into answers(room_id,player_id,issue,question_id,correct,energy,bonus) values(r.id,p.id,p.issue,q.id,correct0,reward,extra);
  feedback:=jsonb_build_object('correct',correct0,'correct_index',array_position(p.ordering,0)-1,'explanation',q.explanation,'reward',reward,'bonus',extra);
  update players set energy=energy+reward+extra,correct=correct+correct0::int,bonus=bonus+extra,attempts=attempts+1,issue=null,locked_until=case when correct0 then now0+interval '200 milliseconds' else now0+interval '1 second' end where id=p.id returning * into p;
  changed:=true;
 when 'state' then null;
 when 'next_question' then null;
 else raise exception '지원하지 않는 기능입니다.';
 end case;
 if changed then
  update room_signals set revision=revision+1 where id=r.id;
  if action<>'submit_answer' then update room_status_signals set revision=revision+1 where id=r.id; end if;
 end if;
 blind:=r.state='running' and (r.manual_blind or (r.auto_blind and now0>=r.ends_at-interval '30 seconds'));
 if is_student and r.state='running' then question0:=mg_issue(p.id,r.topics); end if;
 select coalesce(jsonb_agg(to_jsonb(z) order by z.rank),'[]') into leaders from (select id,nickname,plant,energy,correct,bonus,attempts,mg_stage(energy) stage,row_number() over(order by energy desc,correct desc,joined_at,id) rank from players where room_id=r.id) z;
 if is_student then select x into me from jsonb_array_elements(leaders) x where x->>'id'=p.id::text; if blind then me:=me-'rank'; end if; end if;
 if is_teacher then
  select jsonb_build_object('attempts',count(*),'correct',count(*) filter(where a.correct),'boxes',count(*) filter(where a.bonus>0),'hardest',(select q2.topic from answers a2 join questions q2 on q2.id=a2.question_id where a2.room_id=r.id group by q2.topic having count(*) filter(where not a2.correct)>0 order by avg((not a2.correct)::int) desc,count(*) desc limit 1)) into stats from answers a where a.room_id=r.id;
  with history as (select a.*,pl.nickname,sum(a.energy+a.bonus) over(partition by a.player_id order by a.id)::int as total from answers a join players pl on pl.id=a.player_id where a.room_id=r.id), activity as (
   select nickname,bonus,created_at,'box'::text kind, null::int stage from history where bonus>0
   union all select nickname,bonus,created_at,'growth',mg_stage(total) from history where mg_stage(total)>mg_stage(total-energy-bonus)
   union all select ''::text,0,r.sun_until-interval '20 seconds','sunshine',null::int where r.sun_until is not null
  ) select coalesce(jsonb_agg(to_jsonb(e) order by e.created_at desc),'[]') into events from (select * from activity order by created_at desc limit 5) e;
 end if;
 if blind and is_teacher then select coalesce(jsonb_agg(x-'energy'-'rank'-'correct'-'bonus'-'attempts' order by x->>'nickname'),'[]') into leaders from jsonb_array_elements(leaders) x;
 elsif is_student then
  if r.state='ended' then select coalesce(jsonb_agg(x),'[]') into leaders from (select x from jsonb_array_elements(leaders) x limit 5) s;
  else leaders:='[]'; end if;
 end if;
 return jsonb_build_object('room',jsonb_build_object('id',r.id,'code',r.code,'state',r.state,'topics',r.topics,'duration',r.duration,'bonus',r.bonus,'auto_blind',r.auto_blind,'manual_blind',r.manual_blind,'blind',blind,'starts_at',r.starts_at,'ends_at',r.ends_at,'sun_until',r.sun_until),'server_time',clock_timestamp(),'count',(select count(*) from players where room_id=r.id),'leaders',leaders,'me',me,'question',question0,'feedback',feedback,'stats',stats,'events',events);
end $$;
revoke execute on function public.mg_hash(text),public.mg_stage(int),public.mg_issue(uuid,int[]),public.magic_game(text,jsonb) from public,anon,authenticated;
grant execute on function public.magic_game(text,jsonb) to anon,authenticated;
