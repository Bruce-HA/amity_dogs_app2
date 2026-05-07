create or replace function process_email_import(p_log_id uuid)
returns void
language plpgsql
as $$
declare
  v_log record;

  v_email text;
  v_full_name text;
  v_first_name text;
  v_last_name text;
  v_phone text;
  v_message text;

  v_street text;
  v_suburb_state text;
  v_suburb text;
  v_state text;
  v_postcode text;

  v_person_id uuid;
  v_inquiry_id uuid;
begin
  select *
  into v_log
  from crm_email_import_log
  where id = p_log_id;

  if not found then
    raise exception 'Log not found';
  end if;

  if v_log.import_status = 'imported' then
    raise exception 'Already imported';
  end if;

  v_message := coalesce(v_log.raw_body, '');

  v_email := lower(trim(
    coalesce(
      substring(v_message from '(?i)Email[[:space:]]+([^[:space:]]+@[^[:space:]]+)'),
      v_log.from_email,
      ''
    )
  ));

  v_full_name := nullif(trim(
    coalesce(
        substring(v_message from '(?i)First Name[[:space:]]+(.+?)[[:space:]]+Last Name'),
        substring(v_message from '(?i)Name[[:space:]]+(.+?)[[:space:]]+Email')
    )
    ), '');

  v_first_name := nullif(trim(
    coalesce(
        substring(v_message from '(?i)First Name[[:space:]]+(.+?)[[:space:]]+Last Name'),
        split_part(v_full_name, ' ', 1)
    )
    ), '');

  v_last_name := nullif(trim(
    coalesce(
        substring(v_message from '(?i)Last Name[[:space:]]+(.+?)[[:space:]]+Email'),
        nullif(trim(regexp_replace(v_full_name, '^[^ ]+[ ]*', '')), '')
    )
    ), '');

  if v_first_name is null and v_full_name is not null then
    v_first_name := split_part(v_full_name, ' ', 1);
  end if;

  if v_last_name is null and v_full_name is not null then
    v_last_name := nullif(trim(regexp_replace(v_full_name, '^[^ ]+[ ]*', '')), '');
  end if;

  v_first_name := coalesce(v_first_name, 'Unknown');
  v_last_name := coalesce(v_last_name, 'Unknown');

  v_phone := nullif(trim(coalesce(
    substring(v_message from '(?i)Contact Phone[[:space:]]+(.+?)[[:space:]]+Address'),
    substring(v_message from '(?i)Phone[[:space:]]+(.+?)[[:space:]]+Comment or Message')
  )), '');

  v_street := nullif(trim(
    substring(v_message from '(?i)Address[[:space:]]+([^\r\n]+)')
  ), '');

  v_suburb_state := nullif(trim(
    substring(v_message from '(?i)Address[[:space:]]+[^\r\n]+[[:space:]]+([^\r\n]+)')
  ), '');

  v_postcode := nullif(trim(
    substring(v_message from '(?i)Address[[:space:]]+[^\r\n]+[[:space:]]+[^\r\n]+[[:space:]]+([0-9]{4})')
  ), '');

  if v_suburb_state is not null then
    v_suburb := nullif(trim(split_part(v_suburb_state, ',', 1)), '');
    v_state := nullif(trim(split_part(v_suburb_state, ',', 2)), '');
  end if;

  select people_id
  into v_person_id
  from people
  where lower(coalesce(email_1st, email, '')) = v_email
  limit 1;

  if v_person_id is null then
    insert into people (
      first_name_1st,
      last_name_1st,
      email_1st,
      email,
      phone_1st,
      phone,
      street_address,
      suburb_address,
      state_address,
      postcode_address,
      is_buyer,
      is_prospect,
      created_at
    )
    values (
      v_first_name,
      v_last_name,
      v_email,
      v_email,
      v_phone,
      v_phone,
      v_street,
      v_suburb,
      v_state,
      v_postcode,
      true,
      true,
      now()
    )
    returning people_id into v_person_id;
  else
    update people
    set
      first_name_1st = coalesce(nullif(first_name_1st, ''), v_first_name),
      last_name_1st = coalesce(nullif(last_name_1st, ''), v_last_name),
      phone_1st = coalesce(nullif(phone_1st, ''), v_phone),
      phone = coalesce(nullif(phone, ''), v_phone),
      street_address = coalesce(nullif(street_address, ''), v_street),
      suburb_address = coalesce(nullif(suburb_address, ''), v_suburb),
      state_address = coalesce(nullif(state_address, ''), v_state),
      postcode_address = coalesce(nullif(postcode_address, ''), v_postcode),
      is_buyer = true,
      is_prospect = true
    where people_id = v_person_id;
  end if;

  insert into inquiries (
    person_id,
    status,
    interest_level,
    form_source,
    enquiry_submitted_at,
    created_at
  )
  values (
    v_person_id,
    'new',
    'interested',
    'email_import',
    coalesce(v_log.received_at, now()),
    now()
  )
  returning id into v_inquiry_id;

  insert into communications (
    people_id,
    channel,
    direction,
    subject,
    message_body,
    external_id,
    status,
    created_at
  )
  values (
    v_person_id,
    'email',
    'inbound',
    v_log.subject,
    v_message,
    v_log.message_id,
    'received',
    coalesce(v_log.received_at, now())
  );

  insert into inquiry_notes (
    inquiry_id,
    note_text,
    created_at
  )
  values (
    v_inquiry_id,
    v_message,
    coalesce(v_log.received_at, now())
  );

  update crm_email_import_log
  set
    import_status = 'imported',
    error_message = null,
    created_person_id = v_person_id,
    created_inquiry_id = v_inquiry_id
  where id = p_log_id;

exception
  when others then
    update crm_email_import_log
    set
      import_status = 'failed',
      error_message = sqlerrm
    where id = p_log_id;

    raise;
end;
$$;