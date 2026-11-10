-- CampusConnect student network MVP schema
-- Run in Supabase SQL Editor once, in a new project.
create extension if not exists pgcrypto;
create table if not exists public.colleges(
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  city text,
  created_at timestamptz not null default now()
);
create table if not exists public.college_domains(
  domain text primary key,
  college_id uuid not null references public.colleges(id),
  active boolean not null default true
);
insert into public.colleges(name,city) values
('PES University','Bengaluru'),
('RV College of Engineering','Bengaluru'),
('BMS College of Engineering','Bengaluru')
on conflict (name) do nothing;
-- IMPORTANT: No college email domain is pre-approved.
-- Confirm the institution controls the domain and that it is issued to current students.
-- Then explicitly insert approved student email domains yourself:
-- insert into public.college_domains(domain,college_id)
-- select 'verified-student-domain.example',id from public.colleges where name='PES University';
create or replace function public.is_allowed_student_email(candidate_email text)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.college_domains
 where active=true and lower(domain)=lower(split_part(trim(candidate_email),'@',2)));
$$;
revoke all on function public.is_allowed_student_email(text) from public;
grant execute on function public.is_allowed_student_email(text) to anon,authenticated;

create table if not exists public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check(length(trim(display_name)) between 2 and 80),
 bio text not null default '' check(length(bio)<=500),
 college_id uuid not null references public.colleges(id),
 created_at timestamptz not null default now()
);
create or replace function public.create_profile() returns trigger
language plpgsql security definer set search_path=public as $$
declare selected_college uuid;
begin
 select college_id into selected_college from public.college_domains
 where active and lower(domain)=lower(split_part(new.email,'@',2));
 if selected_college is null then raise exception 'Unapproved college email domain';end if;
 insert into public.profiles(id,display_name,college_id)
 values(new.id,left(coalesce(nullif(trim(new.raw_user_meta_data->>'display_name'),''),'Student'),80),selected_college);
 return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.create_profile();

create table if not exists public.posts(
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(length(trim(body)) between 1 and 3000),
 created_at timestamptz not null default now()
);
create table if not exists public.post_likes(
 post_id uuid references public.posts(id) on delete cascade,
 user_id uuid references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(post_id,user_id)
);
create table if not exists public.comments(
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.posts(id) on delete cascade,
 author_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(length(trim(body)) between 1 and 1000),
 created_at timestamptz not null default now()
);
create table if not exists public.follows(
 follower_id uuid references public.profiles(id) on delete cascade,
 following_id uuid references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(follower_id,following_id),
 check(follower_id<>following_id)
);
create table if not exists public.communities(
 id uuid primary key default gen_random_uuid(),
 name text not null check(length(trim(name)) between 2 and 80),
 description text check(length(description)<=250),
 kind text not null default 'cross_college' check(kind in ('cross_college','college')),
 college_id uuid references public.colleges(id),
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 check((kind='college' and college_id is not null) or (kind='cross_college' and college_id is null))
);
create table if not exists public.community_members(
 community_id uuid references public.communities(id) on delete cascade,
 user_id uuid references public.profiles(id) on delete cascade,
 joined_at timestamptz not null default now(),
 primary key(community_id,user_id)
);
create table if not exists public.direct_messages(
 id uuid primary key default gen_random_uuid(),
 sender_id uuid not null references public.profiles(id),
 recipient_id uuid not null references public.profiles(id),
 body text not null check(length(trim(body)) between 1 and 2000),
 created_at timestamptz not null default now(),
 check(sender_id<>recipient_id)
);
create index if not exists posts_created_idx on public.posts(created_at desc);
create index if not exists comments_post_idx on public.comments(post_id,created_at);
create index if not exists dm_pair_idx on public.direct_messages(sender_id,recipient_id,created_at);

alter table public.colleges enable row level security;
alter table public.college_domains enable row level security;
alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.comments enable row level security;
alter table public.follows enable row level security;
alter table public.communities enable row level security;
alter table public.community_members enable row level security;
alter table public.direct_messages enable row level security;

create policy colleges_read on public.colleges for select to authenticated using(true);
create policy profiles_read on public.profiles for select to authenticated using(true);
create policy profiles_update on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy posts_read on public.posts for select to authenticated using(true);
create policy posts_insert on public.posts for insert to authenticated with check(author_id=auth.uid());
create policy posts_delete on public.posts for delete to authenticated using(author_id=auth.uid());
create policy likes_read on public.post_likes for select to authenticated using(true);
create policy likes_insert on public.post_likes for insert to authenticated with check(user_id=auth.uid());
create policy likes_delete on public.post_likes for delete to authenticated using(user_id=auth.uid());
create policy comments_read on public.comments for select to authenticated using(true);
create policy comments_insert on public.comments for insert to authenticated with check(author_id=auth.uid());
create policy comments_delete on public.comments for delete to authenticated using(author_id=auth.uid());
create policy follows_read on public.follows for select to authenticated using(true);
create policy follows_insert on public.follows for insert to authenticated with check(follower_id=auth.uid());
create policy follows_delete on public.follows for delete to authenticated using(follower_id=auth.uid());
create policy communities_read on public.communities for select to authenticated using(true);
create policy communities_insert on public.communities for insert to authenticated with check(created_by=auth.uid() and kind='cross_college' and college_id is null);
create policy memberships_read on public.community_members for select to authenticated using(true);
create policy memberships_insert on public.community_members for insert to authenticated with check(user_id=auth.uid());
create policy memberships_delete on public.community_members for delete to authenticated using(user_id=auth.uid());
create policy dm_read on public.direct_messages for select to authenticated using(sender_id=auth.uid() or recipient_id=auth.uid());
create policy dm_insert on public.direct_messages for insert to authenticated with check(sender_id=auth.uid());

create or replace function public.protect_profile_identity() returns trigger language plpgsql set search_path=public as $$
begin
 if new.id is distinct from old.id
 or new.college_id is distinct from old.college_id
 or new.created_at is distinct from old.created_at then
 raise exception 'Verified profile identity fields cannot be changed';end if;
 return new;
end;$$;
drop trigger if exists protect_profile_identity_before_update on public.profiles;
create trigger protect_profile_identity_before_update before update on public.profiles for each row execute function public.protect_profile_identity();
-- Supabase realtime publication must include direct_messages.
do $$begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='direct_messages')then
 alter publication supabase_realtime add table public.direct_messages;
 end if;
end$$;
