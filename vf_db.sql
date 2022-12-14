PGDMP         3            
    z            vf_db    14.4    14.4 ?   ?           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            ?           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            ?           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            ?           1262    86845    vf_db    DATABASE     a   CREATE DATABASE vf_db WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'English_India.1252';
    DROP DATABASE vf_db;
                postgres    false                        3079    86846    hstore 	   EXTENSION     >   CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA pg_catalog;
    DROP EXTENSION hstore;
                   false            ?           0    0    EXTENSION hstore    COMMENT     S   COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';
                        false    1                        3079    86974 	   tablefunc 	   EXTENSION     =   CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA public;
    DROP EXTENSION tablefunc;
                   false            ?           0    0    EXTENSION tablefunc    COMMENT     `   COMMENT ON EXTENSION tablefunc IS 'functions that manipulate whole tables, including crosstab';
                        false    3            $           1255    86995    admin_application_search(text)    FUNCTION     ?  CREATE FUNCTION public.admin_application_search(data_text text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
declare
input_jsonb JSONB := data_text;
output_result JSONB :='{}';
BEGIN

DROP Table if exists temp_data;
create table temp_data (
	id serial,
	organization_lid varchar,
	input_text varchar
);

insert into temp_data(organization_lid,input_text)
SELECT t ->> 'organization_lid' AS "organization_lid",
		t ->> 'input_text' AS "input_text" 
			from jsonb_array_elements(input_jsonb['get_application']) AS t;

output_result ['application_details'] := 
(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT oo.name,u.id,u.user_id,r.name as resume_name,ui.f_name || ' ' || ui.l_name as full_name,up.appln_id,up.organization_lid
																  FROM  public.user u
																  INNER JOIN resume r 
																  ON r.user_lid = u.id INNER JOIN user_info ui on ui.user_lid=u.id
																  INNER JOIN user_application up on r.id = up.resume_lid 
									   							  INNER JOIN organization oo  ON oo.organization_id = up.organization_lid AND u.user_id LIKE '%'||(select input_text FROM temp_data)||'%'
 																  AND up.active = true)t);

RETURN output_result;
END
$$;
 ?   DROP FUNCTION public.admin_application_search(data_text text);
       public          postgres    false            &           1255    104018 &   admin_application_search_by_name(text)    FUNCTION     Q  CREATE FUNCTION public.admin_application_search_by_name(data_text text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
declare
input_jsonb JSONB := data_text;
output_result JSONB :='{}';
BEGIN

DROP Table if exists temp_data;
create table temp_data (
	id serial,
	organization_lid varchar,
	input_text varchar
);

insert into temp_data(organization_lid,input_text)
SELECT t ->> 'organization_lid' AS "organization_lid",
		t ->> 'input_text' AS "input_text" 
			from jsonb_array_elements(input_jsonb['get_application']) AS t;

output_result ['application_details'] := 
(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT oo.name,u.id,u.user_id,r.name as resume_name,ui.f_name || ' ' || ui.l_name as full_name,up.appln_id,up.organization_lid
																  FROM  public.user u
																  INNER JOIN resume r 
																  ON r.user_lid = u.id 
                                                                  INNER JOIN user_info ui on ui.user_lid=u.id
																  INNER JOIN user_application up on r.id = up.resume_lid 
									   							  INNER JOIN organization oo  ON oo.organization_id = up.organization_lid
									   							  WHERE UPPER(CONCAT(ui.f_name,ui.l_name)) LIKE '%'||(select input_text FROM temp_data)||'%'
									                       		  AND up.active = true )t);
																  										  
RETURN output_result;
END
$$;
 G   DROP FUNCTION public.admin_application_search_by_name(data_text text);
       public          postgres    false            ?           1255    86996    create_application(text)    FUNCTION     ?  CREATE FUNCTION public.create_application(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE 
      input_jsonb jsonb := input_json;
						  

 BEGIN
  
 drop table if exists temp_application;
 create table temp_application(
  id serial,
  resume_lid int not null,
  organization_lid VARCHAR not null,
  active boolean default(true) not null
 );
 
 	   
	 drop table if exists ids;
	 create temporary table ids(
	 id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	 appln_id int 
	 );
	
 
 insert into temp_application(resume_lid,organization_lid,active)
 select 
       cast(t ->> 'resume_lid' AS int) AS "resume_lid",
	   		t ->> 'organization_lid' AS "organization_lid",
	   cast(t ->> 'active' AS boolean) AS "active"
 from jsonb_array_elements(input_jsonb['create_job_application']) AS t;
 
 with last_ids AS(
	 insert into user_application(resume_lid,organization_lid,active)
	 select resume_lid,organization_lid,active from temp_application
	 RETURNING appln_id
	 )
	 insert into ids(appln_id)
	select appln_id from last_ids;

	
INSERT INTO application_user_info (user_lid,email,f_name,l_name,date_of_birth,pancard_no,aadhar_card_no,temp_email,gender_lid,pancard_url_path, profile_url_path,aadhar_card_url_path,nationality,resume_lid,application_lid)
select user_lid,email,f_name,l_name,date_of_birth,pancard_no,aadhar_card_no,temp_email,gender_lid,pancard_url_path, profile_url_path,aadhar_card_url_path,nationality,resume_lid,(select appln_id from ids) from user_info
where user_info.resume_lid = (select resume_lid from temp_application);
 
INSERT INTO application_user_address(user_lid, address, address_type_lid,city,pin_code,resume_lid,application_lid)
SELECT user_lid, address, address_type_lid,city,pin_code,resume_lid,(select appln_id from ids) FROM user_address
where user_address.resume_lid = (select resume_lid from temp_application);

INSERT INTO application_user_contact(user_lid,contact_number,temp_contact_number,resume_lid,application_lid)
select user_lid ,contact_number,temp_contact_number,resume_lid,(select appln_id from ids) from user_contact
where user_contact.resume_lid = (select resume_lid from temp_application);

insert into application_resume_qualification(resume_qualification_lid,resume_lid,qualification_type_lid,topic_of_study,university,institute,percentile,year_of_passing,url_path, is_completed,application_lid)	 
select resume_qualification_lid,resume_lid,qualification_type_lid,topic_of_study,university,institute,percentile,year_of_passing,url_path, is_completed,(select appln_id from ids) from resume_qualification
where resume_qualification.resume_lid = (select resume_lid from temp_application);

insert into application_resume_experience(resume_experience_lid,resume_lid,experience_type_lid,employer_name,designation,designation_lid,description,start_date,end_date,responsibilities,is_current,duration,padagogy,application_lid)
select resume_experience_lid,resume_lid,experience_type_lid,employer_name,designation,designation_lid,description,start_date,end_date,responsibilities,is_current,duration,padagogy,(select appln_id from ids) from resume_experience
where resume_experience.resume_lid = (select resume_lid from temp_application);

insert into application_resume_skill_selected(resume_skill_selected_lid,resume_lid,skill_lid,application_lid)
select resume_skill_selected_lid,resume_lid,skill_lid,(select appln_id from ids)  from resume_skill_selected
where resume_skill_selected.resume_lid = (select resume_lid from temp_application);

insert into application_resume_achievement(resume_achievement_lid,resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration,application_lid)
select resume_achievement_lid,resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration,(select appln_id from ids) from resume_achievement 
where resume_achievement.resume_lid = (select resume_lid from temp_application);
 
insert into application_resume_publication(resume_publication_lid,resume_achievement_lid,publication_role,no_of_authors,publisher,year_of_publication,publication_url_path,application_lid)
select rp.resume_publication_lid,rp.resume_achievement_lid,rp.publication_role,rp.no_of_authors,rp.publisher,rp.year_of_publication,rp.publication_url_path,(select appln_id from ids)
from resume_publication rp INNER JOIN resume_achievement ra ON rp.resume_achievement_lid = ra.resume_achievement_lid
AND ra.resume_lid = (select resume_lid from temp_application) AND ra.achievement_type_lid = 1;

insert into application_resume_research(resume_research_lid,resume_achievement_lid,volume_year,category,description,research_url_path,application_lid)
select rr.resume_research_lid,rr.resume_achievement_lid,rr.volume_year,rr.category,rr.description,rr.research_url_path,(select appln_id from ids)
from resume_research rr inner join resume_achievement ra on rr.resume_achievement_lid = ra.resume_achievement_lid
AND ra.resume_lid = (select resume_lid from temp_application) AND ra.achievement_type_lid = 3;

insert into application_bank_details(user_lid,bank_account_type_lid,resume_lid,bank_name,branch_name,ifsc_code,micr_code,account_number,url_path,application_lid)	 
select user_lid,bank_account_type_lid,resume_lid,bank_name,branch_name,ifsc_code,micr_code,account_number,url_path,(select appln_id from ids) from bank_details
where bank_details.resume_lid = (select resume_lid from temp_application);

 RETURN '{"status": 200, "message": "Successfull."}';

END
$$;
 :   DROP FUNCTION public.create_application(input_json text);
       public          postgres    false                       1255    86997    discontinue_faculty(text)    FUNCTION     ?  CREATE FUNCTION public.discontinue_faculty(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
	
DECLARE
	input_jsonb JSONB := input_json;
    
BEGIN

   DROP TABLE IF EXISTS temp_data;
   CREATE TEMPORARY TABLE temp_data (
    id SERIAL,
    proforma_lid INT NOT NULL,
	organization_lid VARCHAR NOT NULL,
	comment VARCHAR(255) NOT NULL,
	created_by varchar(100) NOT NULL,
    is_discontinued BOOLEAN
 );
 
 INSERT INTO temp_data(proforma_lid,organization_lid,comment,created_by,is_discontinued)
 SELECT cast(t ->> 'proforma_lid' AS integer),
		 t ->> 'organization_lid' ,
		 t ->> 'comment',
		 t ->> 'created_by',
		 CAST(t ->> 'is_discontinued' AS BOOLEAN)
 FROM jsonb_array_elements(input_jsonb['insert_discontinue']) AS t;

	    INSERT INTO discontinue_details(proforma_lid,organization_lid,comment,created_by,is_discontinued)	 
	    SELECT proforma_lid,organization_lid,comment,created_by,is_discontinued FROM temp_data;
        
        UPDATE approved_faculty_status SET is_discontinued = (SELECT is_discontinued FROM temp_data) WHERE proforma_lid = (SELECT proforma_lid FROM temp_data);
	
RETURN '{"status":200, "message":"Successfull"}';
	
END;	
$$;
 ;   DROP FUNCTION public.discontinue_faculty(input_json text);
       public          postgres    false            ?           1255    86998     faculty_application_search(text)    FUNCTION       CREATE FUNCTION public.faculty_application_search(input_text text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
output_result JSONB :='{}';
BEGIN
output_result ['application_details'] := 
(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT oo.name,u.id,u.user_id,r.name as resume_name,ui.f_name || ' ' || ui.l_name as full_name,up.appln_id,up.organization_lid
																  FROM  public.user u
																  INNER JOIN resume r 
																  ON r.user_lid = u.id INNER JOIN user_info ui on ui.user_lid=u.id
																  INNER JOIN user_application up on r.id = up.resume_lid
									   							  INNER JOIN organization oo ON oo.organization_id = up.organization_lid
									   							  AND u.id = cast(t ->> input_text AS int )) t);

RETURN output_result;
END
$$;
 B   DROP FUNCTION public.faculty_application_search(input_text text);
       public          postgres    false            ?           1255    86999    faculty_resume_search(text)    FUNCTION     ?  CREATE FUNCTION public.faculty_resume_search(input_text text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
output_result JSONB :='{}';
BEGIN
output_result ['resume_details'] := (SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT  r.name AS resume_name,u.user_id,u.id as user_lid,ui.f_name,ui.l_name 
																  FROM  public.user u
																  LEFT JOIN user_info ui 
																  ON ui.user_lid = u.id
																  INNER JOIN user_role ur ON ur.user_lid = u.id
									   							  LEFT JOIN resume r ON r.user_lid = u.id
																  WHERE u.user_id LIKE '%'||UPPER(input_text)||'%' AND ur.role_lid = 2) t);

RETURN output_result;
END
$$;
 =   DROP FUNCTION public.faculty_resume_search(input_text text);
       public          postgres    false            ?           1255    87000    faculty_search_by_name(text)    FUNCTION     ?  CREATE FUNCTION public.faculty_search_by_name(input_text text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
declare
output_result JSONB :='{}';
BEGIN
output_result ['resume_details'] := (SELECT jsonb_agg(to_jsonb(t.*))  FROM (SELECT r.name AS resume_name,u.user_id,u.id as user_lid,ui.f_name,ui.l_name 
																	  FROM public.user u
																	  INNER JOIN user_info ui 
																	  ON ui.user_lid = u.id
																	  LEFT JOIN resume r ON r.user_lid = u.id
																	  INNER JOIN user_role ur ON ur.user_lid = u.id
																	  WHERE UPPER(CONCAT(ui.f_name,ui.l_name)) LIKE '%'||input_text||'%' AND ur.role_lid = 2) t);

RETURN output_result;
END
$$;
 >   DROP FUNCTION public.faculty_search_by_name(input_text text);
       public          postgres    false            ?           1255    87001    filter_proforma(text)    FUNCTION     ?  CREATE FUNCTION public.filter_proforma(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$

-- DO $$
DECLARE

input_jsonb jsonb := input_json;

-- '{
--   "insert_proforma_status": [
--     {
--       "proforma_lid": 3,
--       "level": 3,
--       "status_lid": 2,
--       "comment": "Very Poor",
--       "file_path": "path"
--     }
--   ]
-- }'
  

BEGIN

DROP TABLE IF EXISTS temp_proforma_status;
CREATE TEMPORARY TABLE temp_proforma_status(
id serial,
proforma_lid int NOT NULL,
approved_by varchar,
level int NOT NULL,
status_lid int NOT NULL,
comment varchar,
created_date timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
file_path varchar,
active boolean  NOT NULL DEFAULT(true)
);

INSERT INTO temp_proforma_status(proforma_lid,approved_by,level,status_lid,comment,file_path)
select cast(t ->> 'proforma_lid' AS int) "proforma_lid",
            t ->> 'approved_by' AS  "approved_by",
	   CAST(t ->> 'level' AS int ) "level",
	   CAST(t ->> 'status_lid' AS int ) "status_lid",
	        t ->> 'comment' AS  "comment",
	        t ->> 'file_path' AS "file_path"
FROM jsonb_array_elements(input_jsonb['insert_proforma_status']) AS t;		
	
	CASE (SELECT status_lid from temp_proforma_status)
    WHEN 1 THEN 
			
	  IF(select level from temp_proforma_status) = 1 THEN

			INSERT INTO proforma_status(proforma_lid,approved_by,level,status_lid,comment,file_path,tag_id)
			SELECT tps.proforma_lid,tps.approved_by,tps.level,tps.status_lid,tps.comment,tps.file_path,pd.tag_id + 1 
			FROM temp_proforma_status tps INNER JOIN proforma_details pd on pd.proforma_id = tps.proforma_lid ;

			UPDATE proforma_details set tag_id = (SELECT tag_id FROM proforma_details WHERE proforma_id = (SELECT proforma_lid FROM temp_proforma_status)) + 1,
			status_lid = (SELECT status_lid FROM temp_proforma_status),
			modified_by = (SELECT approved_by FROM temp_proforma_status),
			level = (SELECT level FROM temp_proforma_status) + 1  WHERE proforma_id = (SELECT proforma_lid FROM temp_proforma_status);

		ELSE 
		
		    INSERT INTO proforma_status(proforma_lid,approved_by,level,status_lid,comment,file_path,tag_id)
		    select tps.proforma_lid,tps.approved_by,tps.level,tps.status_lid,tps.comment,tps.file_path,pd.tag_id
		    FROM temp_proforma_status tps INNER JOIN proforma_details pd
            ON pd.proforma_id = tps.proforma_lid ;

			UPDATE proforma_details SET status_lid = (SELECT status_lid FROM temp_proforma_status),
			modified_by = (SELECT approved_by FROM temp_proforma_status),
			level = (SELECT level FROM temp_proforma_status) + 1 WHERE proforma_id = (SELECT proforma_lid FROM temp_proforma_status);

		END IF;		
		
    WHEN 2 THEN 
			
			INSERT INTO proforma_status(proforma_lid,approved_by,level,status_lid,comment,file_path,tag_id)
		    SELECT tps.proforma_lid,tps.approved_by,tps.level,tps.status_lid,tps.comment,tps.file_path,pd.tag_id
		    FROM temp_proforma_status tps INNER JOIN proforma_details pd 
            ON pd.proforma_id = tps.proforma_lid ;

			UPDATE proforma_details SET status_lid = (select status_lid from temp_proforma_status),
			modified_by = (SELECT approved_by FROM temp_proforma_status),
			level = (SELECT level FROM temp_proforma_status) WHERE proforma_id = (SELECT proforma_lid FROM temp_proforma_status);
			
    WHEN 3 THEN
	
			INSERT INTO proforma_status(proforma_lid,approved_by,level,status_lid,comment,file_path,tag_id)
		    SELECT tps.proforma_lid,tps.approved_by,1,tps.status_lid,tps.comment,tps.file_path,pd.tag_id
		    FROM temp_proforma_status tps INNER JOIN proforma_details pd 
            ON pd.proforma_id = tps.proforma_lid ;

			UPDATE proforma_details SET status_lid = (SELECT status_lid FROM temp_proforma_status),
			modified_by = (SELECT approved_by FROM temp_proforma_status),
			level = 1 WHERE proforma_id = (SELECT proforma_lid FROM temp_proforma_status);
			
    WHEN 4 THEN
	
			INSERT INTO proforma_status(proforma_lid,approved_by,level,status_lid,comment,file_path,tag_id)
		    SELECT tps.proforma_lid,tps.approved_by,tps.level,tps.status_lid,tps.comment,tps.file_path,pd.tag_id
		    FROM temp_proforma_status tps INNER JOIN proforma_details pd 
            ON pd.proforma_id = tps.proforma_lid ;

			UPDATE proforma_details SET status_lid = (SELECT status_lid FROM temp_proforma_status),
			modified_by = (SELECT approved_by FROM temp_proforma_status),
			level = (SELECT level FROM temp_proforma_status) WHERE proforma_id = (SELECT proforma_lid FROM temp_proforma_status);
	END CASE;
	

	 RETURN '{"status":200, "message":"Successfull"}';
	
	END;	
 
$_$;
 7   DROP FUNCTION public.filter_proforma(input_json text);
       public          postgres    false            ?           1255    87002    get_all_approved_proforma()    FUNCTION     ?  CREATE FUNCTION public.get_all_approved_proforma() RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result JSONB := '{}';

BEGIN

	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t1.*)) FROM (SELECT pd.module,pd.program_name,pd.acad_session,ua.organization_lid,pd.proforma_id,
                                                                                  concat(f_name,' ',l_name) AS full_name,pancard_no,afs.is_discontinued FROM proforma_details pd
                                          INNER JOIN approved_faculty_status afs ON pd.proforma_id = afs.proforma_lid
                                          INNER JOIN user_application ua ON ua.appln_id = pd.application_lid
                                          INNER JOIN resume r ON r.id = ua.resume_lid 
                                          INNER JOIN user_info ui ON ui.user_lid = r.user_lid)t1);

RETURN output_result;
END
$$;
 2   DROP FUNCTION public.get_all_approved_proforma();
       public          postgres    false            %           1255    87003    get_all_proforma(text)    FUNCTION     ?  CREATE FUNCTION public.get_all_proforma(input_data text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
input_jsonb JSONB := input_data;
level_text int := input_jsonb['level'];
--organization_lid JSONB := jsonb_array_elements(input_jsonb['organization_lid']);
output_result JSONB := '{}';

BEGIN

DROP TABLE IF EXISTS temp_ids;
CREATE TEMPORARY TABLE temp_ids (
	id serial,
	organization_lid varchar
);

INSERT INTO temp_ids(organization_lid)
SELECT t ->> 'organization_lid' 
FROM jsonb_array_elements(input_jsonb['organization_lid']) AS t;

IF(level_text) IN(1,2) THEN

	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid)
	FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
	TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id,pd.status_lid, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
	pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid AND pd.status_lid IN (1,3)
	AND pd.level = (level_text) AND pd.active = TRUE AND ua.organization_lid In (SELECT organization_lid FROM temp_ids)
	ORDER BY pd.created_date) t1 
INNER JOIN 
	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

 ELSIF (level_text) = 3 THEN
 
	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid AND pd.status_lid IN (1,2)
    WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level = 3 and status_lid = 1)
	AND pd.active = TRUE	ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

ELSE 

    output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid AND pd.status_lid IN (1,3)
	AND pd.level = (level_text)  AND pd.active = TRUE
	ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;
	
END IF;
RETURN output_result;
END
$$;
 8   DROP FUNCTION public.get_all_proforma(input_data text);
       public          postgres    false            )           1255    87004    get_all_proforma_report(text)    FUNCTION     ?  CREATE FUNCTION public.get_all_proforma_report(input_data text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
input_jsonb JSONB := input_data;
level_text int := input_jsonb['level'];
output_result JSONB := '{}';

BEGIN

DROP TABLE IF EXISTS temp_ids;
CREATE TEMPORARY TABLE temp_ids (
	id serial,
	organization_lid varchar
);

INSERT INTO temp_ids(organization_lid)
SELECT t ->> 'organization_lid' 
FROM jsonb_array_elements(input_jsonb['organization_lid']) AS t;

IF(level_text) IN(1,2) THEN

	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
	TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,pd.commencement_date_of_program,
	pd.aol_obe, pd.level, ua.appln_id,pd.status_lid, pd.modified_by,pd.commencement_date_of_program, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > (level_text) and status_lid IN(1,2,3,4) OR pd.level = (level_text) AND status_lid = 2)
	AND ua.organization_lid IN(SELECT organization_lid FROM temp_ids) ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 );

ELSE 

	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
	TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
	pd.aol_obe, pd.level ,pd.status_lid , ua.appln_id, pd.modified_by,pd.commencement_date_of_program, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > (level_text) and status_lid IN(1,2,3,4) OR pd.level = (level_text) AND status_lid IN (2,4))
	AND pd.active = TRUE
	ORDER BY pd.created_date) t1 
	INNER JOIN 
	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;
END IF;
RETURN output_result;
END
$$;
 ?   DROP FUNCTION public.get_all_proforma_report(input_data text);
       public          postgres    false            (           1255    104609 #   get_all_proforma_report_excel(text)    FUNCTION     ?  CREATE FUNCTION public.get_all_proforma_report_excel(input_data text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
input_jsonb JSONB := input_data;
level_text int := input_jsonb['level'];
output_result JSONB := '{}';

BEGIN

DROP TABLE IF EXISTS temp_ids;
CREATE TEMPORARY TABLE temp_ids (
	id serial,
	organization_lid varchar
);

INSERT INTO temp_ids(organization_lid)
SELECT t ->> 'organization_lid' 
FROM jsonb_array_elements(input_jsonb['organization_lid']) AS t;

IF(level_text) IN(1,2) THEN

output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*))
FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp, max_points_2(t2.application_lid), t4.qual_list 
FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session, TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,pd.commencement_date_of_program,
pd.aol_obe, pd.level, ua.appln_id, pd.modified_by,pd.commencement_date_of_program, ua.organization_lid, ap.name AS status 
FROM proforma_details pd 
INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
INNER JOIN application_status ap on ap.id = pd.status_lid 
INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > 1 AND status_lid IN(1,2,3))
OR pd.proforma_id IN (SELECT proforma_id FROM proforma_details WHERE level = 1 AND status_lid = 2) ORDER BY pd.created_date) t1 
    
INNER JOIN 
    
(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
INNER JOIN experience_type et ON et.id = ar.experience_type_lid
GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
ON t2.application_lid = t1.application_lid
    
INNER JOIN
    
(SELECT application_lid, REPLACE(JSONB_AGG(obj)::TEXT, '}, {', ', ') AS qual_list FROM (SELECT application_lid, JSONB_BUILD_OBJECT(qt.abbr, STRING_AGG(topic_of_study, ', ')) AS obj 
FROM application_resume_qualification q INNER JOIN qualification_type qt ON qt.id = q.qualification_type_lid 
GROUP BY application_lid, qt.abbr) t1
GROUP BY application_lid) t4
ON t4.application_lid = t1.application_lid) t3);

ELSE 

	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*))
FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp, max_points_2(t2.application_lid), t4.qual_list 
FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session, TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,pd.commencement_date_of_program,
pd.aol_obe, pd.level, ua.appln_id, pd.modified_by,pd.commencement_date_of_program, ua.organization_lid, ap.name AS status 
FROM proforma_details pd 
INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
INNER JOIN application_status ap on ap.id = pd.status_lid 
INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > 1 AND status_lid IN(1,2,3))
OR pd.proforma_id IN (SELECT proforma_id FROM proforma_details WHERE level = 1 AND status_lid = 2) ORDER BY pd.created_date) t1 
    
INNER JOIN 
    
(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
INNER JOIN experience_type et ON et.id = ar.experience_type_lid
GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
ON t2.application_lid = t1.application_lid
    
INNER JOIN
    
(SELECT application_lid, REPLACE(JSONB_AGG(obj)::TEXT, '}, {', ', ') AS qual_list FROM (SELECT application_lid, JSONB_BUILD_OBJECT(qt.abbr, STRING_AGG(topic_of_study, ', ')) AS obj 
FROM application_resume_qualification q INNER JOIN qualification_type qt ON qt.id = q.qualification_type_lid 
GROUP BY application_lid, qt.abbr) t1
GROUP BY application_lid) t4
ON t4.application_lid = t1.application_lid) t3) ;
END IF;
RETURN output_result;
END
$$;
 E   DROP FUNCTION public.get_all_proforma_report_excel(input_data text);
       public          postgres    false            ?           1255    87005 '   get_application_resume_experience(text)    FUNCTION       CREATE FUNCTION public.get_application_resume_experience(input_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result JSONB :='{}';
input_jsonb JSONB := input_id;
BEGIN

DROP TABLE IF EXISTS temp_data;
CREATE TABLE temp_data (
	id serial,
	application_lid int,
	experience_type_lid int
);

INSERT INTO temp_data(application_lid,experience_type_lid)
SELECT cast(t ->> 'application_lid' AS int) AS "application_lid",
	   cast(t ->> 'experience_type_lid' AS int) AS "experience_type_lid"
FROM jsonb_array_elements(input_jsonb['get_application_experience']) AS t;

output_result['application_resume_experience'] :=(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT ae.* FROM user_application up INNER JOIN application_resume_experience ae  
																						   ON up.appln_id = ae.application_lid  
																						   AND ae.experience_type_lid = (SELECT experience_type_lid FROM temp_data)
																						   AND ae.application_lid = (SELECT application_lid FROM temp_data))t);

RETURN output_result;
END
$$;
 G   DROP FUNCTION public.get_application_resume_experience(input_id text);
       public          postgres    false            ?           1255    87006 *   get_application_resume_qualification(text)    FUNCTION     h  CREATE FUNCTION public.get_application_resume_qualification(input_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result JSONB :='{}';
input_jsonb JSONB := input_id;
BEGIN

DROP TABLE IF EXISTS temp_data;
CREATE TABLE temp_data (
	id serial,
	application_lid int,
	qualification_type_lid int
);

INSERT INTO temp_data(application_lid,qualification_type_lid)
SELECT cast(t ->> 'application_lid' AS int) AS "application_lid",
	   cast(t ->> 'qualification_type_lid' AS int) AS "qualification_type_lid"
FROM jsonb_array_elements(input_jsonb['get_application_qualification']) AS t;
output_result['application_resume_qualification'] :=(SELECT jsonb_agg(to_jsonb(t.*)) FROM (select aq.institute,aq.topic_of_study,aq.university,aq.year_of_passing from user_application up INNER JOIN application_resume_qualification aq  
																						   on up.appln_id = aq.application_lid  
																						   AND aq.qualification_type_lid = (SELECT qualification_type_lid from temp_data)
																						   AND aq.application_lid = (SELECT application_lid from temp_data))t);

RETURN output_result;
END
$$;
 J   DROP FUNCTION public.get_application_resume_qualification(input_id text);
       public          postgres    false            ?           1255    87007    get_appln_details(text)    FUNCTION     ?  CREATE FUNCTION public.get_appln_details(input_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result JSONB :='{}';

BEGIN
output_result ['personal_details'] :=(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT u.id, u.user_id, ua.address,ua.address_type_lid,ua.city,ua.pin_code,ui.email,ui.f_name,ui.l_name,
ui.date_of_birth,ui.pancard_no,ui.aadhar_card_no,ui.temp_email,ui.profile_url_path,ui.gender_lid,gd.name,ui.pancard_url_path,
ui.aadhar_card_url_path,ui.nationality,uc.contact_number,uc.temp_contact_number FROM public.user u
INNER JOIN application_user_info ui ON ui.user_lid = u.id
INNER JOIN user_gender gd ON gd.id = ui.gender_lid
INNER JOIN user_application us ON us.appln_id = ui.application_lid
INNER JOIN application_user_address ua ON ua.application_lid = us.appln_id
INNER JOIN application_user_contact uc ON uc.application_lid = us.appln_id
WHERE
us.appln_id = CAST(input_id AS INT) AND
u.active = TRUE AND 
ui.active = TRUE AND 
ua.active = TRUE AND 
uc.active = TRUE)t);

output_result['resume_qualification'] := (SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT qt.abbr,qt.name,rq.is_completed,rq.resume_qualification_lid,rq.qualification_type_lid,rq.topic_of_study,rq.resume_lid,
rq.university,rq.institute,rq.percentile,rq.year_of_passing,rq.url_path FROM application_resume_qualification rq
INNER JOIN user_application us ON us.appln_id = rq.application_lid
INNER JOIN qualification_type qt ON qt.id = rq.qualification_type_lid
WHERE us.appln_id = CAST(input_id AS INT) AND rq.application_lid = CAST(input_id AS INT) AND rq.active = true)t);

output_result['resume_experience'] := (SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT  re.padagogy,et.abbr,re.resume_experience_lid,re.experience_type_lid,re.employer_name,re.resume_lid,
re.designation,re.designation_lid,re.description,TO_CHAR(re.start_date,'DD-MM-YYYY') as start_date,TO_CHAR(re.end_date,'DD-MM-YYYY') as end_date ,re.responsibilities,re.is_current,re.duration
FROM application_resume_experience  re
INNER JOIN user_application us ON us.appln_id = re.application_lid
INNER JOIN experience_type et on et.id = re.experience_type_lid	
WHERE us.appln_id = CAST(input_id AS INT) AND re.application_lid = CAST(input_id AS INT)  AND re.active = true) t);

output_result['resume_achievement'] :=
 (SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT ot.name,ra.resume_achievement_lid,ra.achievement_type_lid,ra.title,ra.description,ra.resume_lid,
ra.organization_name,ra.organization_type_lid,ra.url_path,TO_CHAR(ra.achievement_date,'DD-MM-YYYY') AS achievement_date,ra.duration
from application_resume_achievement ra 
INNER JOIN user_application us ON us.appln_id = ra.application_lid
INNER JOIN achievement_type att ON att.id = ra.achievement_type_lid
INNER JOIN organization_type ot ON ot.id = ra.organization_type_lid
WHERE us.appln_id = CAST(input_id AS INT) AND ra.application_lid = CAST(input_id AS INT)  AND ra.achievement_type_lid = 2 AND ra.active = TRUE AND att.active = true)t);

output_result['resume_publication'] :=(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT rp.resume_achievement_lid,rp.publication_role,rp.no_of_authors,rp.publisher,ra.title,rp.year_of_publication,rp.publication_url_path
FROM application_resume_publication rp
INNER JOIN application_resume_achievement ra ON ra.resume_achievement_lid = rp.resume_achievement_lid
WHERE rp.application_lid = CAST(input_id AS INT) AND ra.application_lid = CAST(input_id AS INT) AND ra.achievement_type_lid = 1 AND rp.active = TRUE AND ra.active = true)t);

output_result['resume_research'] :=(SELECT jsonb_agg(to_jsonb(t.*))FROM (SELECT rr.resume_achievement_lid,ra.title,rr.volume_year,ra.description,rr.category,rr.research_url_path
FROM application_resume_research rr
INNER JOIN application_resume_achievement ra ON ra.resume_achievement_lid = rr.resume_achievement_lid
WHERE rr.application_lid = CAST(input_id AS INT) AND ra.application_lid = CAST(input_id AS INT) AND ra.achievement_type_lid = 3 AND rr.active = TRUE AND ra.active = TRUE)t);

output_result['proforma_details'] :=(SELECT jsonb_agg(to_jsonb(t.*))FROM (SELECT * FROM proforma_details pd INNER JOIN user_application ap ON ap.appln_id = pd.application_lid
																		 WHERE ap.appln_id = CAST(input_id AS INT) AND pd.level = 1 AND pd.active = true)t);
																		 
output_result['organization_id'] :=(SELECT jsonb_agg(to_jsonb(t.*))FROM (SELECT organization_lid FROM user_application where appln_id = CAST(input_id AS INT))t);

RETURN output_result;
END
$$;
 7   DROP FUNCTION public.get_appln_details(input_id text);
       public          postgres    false            ?           1255    87008    get_bank_details(text)    FUNCTION     _  CREATE FUNCTION public.get_bank_details(input_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result JSONB :='{}';

BEGIN

output_result['bank_details'] :=
(SELECT to_jsonb(t.*) FROM (SELECT bc.abbr,bd.user_lid,bd.bank_account_type_lid,bc.account_type,bd.bank_name,bd.branch_name,
bd.ifsc_code,bd.micr_code,bd.account_number,bd.url_path
FROM bank_details bd
INNER JOIN resume r ON r.user_lid = bd.user_lid
INNER JOIN bank_account_type bc ON bc.id = bd.bank_account_type_lid
WHERE r.id = CAST(input_id AS INT) AND bd.active = TRUE AND bc.active = TRUE)t);
RETURN output_result;
END
$$;
 6   DROP FUNCTION public.get_bank_details(input_id text);
       public          postgres    false            ?           1255    87009    get_comments(integer)    FUNCTION     :  CREATE FUNCTION public.get_comments(input_id integer) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

	DECLARE
	output_result JSONB :='{}';
    
	BEGIN
	
	output_result ['comments'] := (SELECT JSONB_AGG(TO_JSONB(t.*)) FROM
	(SELECT ps.comment,ps.approved_by,TO_CHAR(ps.created_date,'DD-MM-YYYY')as created_date FROM proforma_details pd INNER JOIN proforma_status ps ON ps.tag_id = pd.tag_id AND ps.tag_id = (SELECT tag_id from proforma_details WHERE proforma_id = input_id ) AND pd.proforma_id = input_id
	AND ps.proforma_lid = input_id) t);
RETURN output_result;
END
$$;
 5   DROP FUNCTION public.get_comments(input_id integer);
       public          postgres    false            +           1255    128315    get_created_offer_letter(text)    FUNCTION       CREATE FUNCTION public.get_created_offer_letter(user_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
output_result JSONB :='{}';
BEGIN
output_result ['generated_offer_letter'] := 
(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT pd.proforma_id, ofd.status, pd.acad_session, pd.module as subject, pd.program_name, o.name as school_name
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN organization o ON ua.organization_lid = o.organization_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info aui on pd.application_lid = aui.application_lid 
    INNER JOIN offer_letter_details ofd on pd.proforma_id =ofd.proforma_id
	WHERE aui.pancard_no = user_id) t);

RETURN output_result;
END
$$;
 =   DROP FUNCTION public.get_created_offer_letter(user_id text);
       public          postgres    false            ,           1255    128330 )   get_created_offer_letter_admin_side(text)    FUNCTION     ?  CREATE FUNCTION public.get_created_offer_letter_admin_side(user_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
output_result JSONB :='{}';
BEGIN
output_result ['offer_letter_details_admin'] := (SELECT jsonb_agg(to_jsonb(t.*)) 
											 FROM (SELECT pd.proforma_id, ofd.status,ofd.approved_by, pd.acad_session,  CONCAT(aui.f_name,' ',aui.l_name) AS full_name,aui.pancard_no, pd.module as subject, 
												   pd.program_name, o.name as school_name
												  FROM proforma_details pd 
												  INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
												  INNER JOIN organization o ON ua.organization_lid = o.organization_id
											 	  INNER JOIN application_status ap on ap.id = pd.status_lid 
											 	  INNER JOIN application_user_info aui on pd.application_lid = aui.application_lid 
												  INNER JOIN offer_letter_details ofd on pd.proforma_id =ofd.proforma_id
												  WHERE pd.created_by = user_id) t);
RETURN output_result;
END
$$;
 H   DROP FUNCTION public.get_created_offer_letter_admin_side(user_id text);
       public          postgres    false            -           1255    135853 *   get_detail_for_offer_letter(integer, text)    FUNCTION     ?  CREATE FUNCTION public.get_detail_for_offer_letter(prof_id integer, user_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
output_result JSONB :='{}';
BEGIN
output_result := 
(SELECT (to_jsonb(t.*)) FROM (SELECT TO_CHAR(pd.last_modified_date::date, 'dd/mm/yyyy') AS date, aua.address AS address, aua.city AS city, CONCAT(aui.f_name,' ',aui.l_name) AS faculty_name, 
       o.name AS school, pd.acad_session AS acad_session, CONCAT(aui.f_name,' ',aui.l_name) AS full_name,aui.pancard_no, pd.program_name AS program_name, date_part('year',pd.commencement_date_of_program) AS acad_year, 
	   pd.rate_per_hours AS rate_per_hour, pd.module AS module_description
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN organization o ON ua.organization_lid = o.organization_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info aui on pd.application_lid = aui.application_lid 
	INNER JOIN application_user_address aua on pd.application_lid = aua.application_lid
	WHERE pd.proforma_id = prof_id AND aua.address_type_lid = 1  AND aui.pancard_no = user_id ) t);

RETURN output_result;
END
$$;
 Q   DROP FUNCTION public.get_detail_for_offer_letter(prof_id integer, user_id text);
       public          postgres    false            ?           1255    104423 "   get_discontinued_comments(integer)    FUNCTION     #  CREATE FUNCTION public.get_discontinued_comments(input_id integer) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

	DECLARE
	output_result JSONB :='{}';
    
	BEGIN
	
	output_result ['comments'] :=  (SELECT JSONB_AGG(TO_JSONB(t.*)) FROM
	(SELECT dd.comment,dd.created_by,TO_CHAR(dd.created_date,'DD-MM-YYYY')as created_date,dd.is_discontinued FROM approved_faculty_status afs INNER JOIN discontinue_details dd ON dd.proforma_lid = afs.proforma_lid  AND afs.proforma_lid =  input_id
	AND dd.proforma_lid = input_id) t);
RETURN output_result;
END
$$;
 B   DROP FUNCTION public.get_discontinued_comments(input_id integer);
       public          postgres    false            ?           1255    128292 '   get_faculty_application_status(integer)    FUNCTION     ?  CREATE FUNCTION public.get_faculty_application_status(prof_id integer) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
output_result JSONB :='{}';
BEGIN
output_result ['application_status_details'] := 
(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT pd.acad_session, pd.module, pd.program_name, 
									   pd.created_date::date, aui.pancard_no, CONCAT(aui.f_name, ' ', aui.l_name) AS full_name,
									   pd.level, pd.status_lid, pd.proforma_id
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info aui on pd.application_lid = aui.application_lid 
	WHERE pd.proforma_id = prof_id) t);

RETURN output_result;
END
$$;
 F   DROP FUNCTION public.get_faculty_application_status(prof_id integer);
       public          postgres    false            !           1255    87010    get_faculty_applications(text)    FUNCTION       CREATE FUNCTION public.get_faculty_applications(data_text text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result JSONB :='{}';
BEGIN

output_result ['application_details'] := 
(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT oo.name,r.id AS resume_lid,u.id,u.user_id,r.name as resume_name,ui.f_name || ' ' || ui.l_name as full_name,up.active,up.appln_id,up.organization_lid
																  FROM  public.user u
																  INNER JOIN resume r 
																  ON r.user_lid = u.id INNER JOIN user_info ui ON ui.user_lid=u.id
																  INNER JOIN user_application up ON r.id = up.resume_lid 
									   							  INNER JOIN organization oo ON oo.organization_id = up.organization_lid
									   							  AND u.user_id = data_text)t);

RETURN output_result;
END
$$;
 ?   DROP FUNCTION public.get_faculty_applications(data_text text);
       public          postgres    false            ?           1255    87011    get_personal_details(text)    FUNCTION     ?  CREATE FUNCTION public.get_personal_details(input_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result JSONB :='{}';
BEGIN

output_result ['personal_details'] := (SELECT to_jsonb(t.*) FROM (SELECT u.id, u.user_id, ua.address,ua.address_type_lid,ua.city,ua.pin_code,ui.email,ui.f_name,ui.l_name,
ui.date_of_birth,ui.pancard_no,ui.aadhar_card_no,ui.temp_email,ui.gender_lid,gd.name,ui.pancard_url_path,
ui.aadhar_card_url_path,ui.nationality,uc.contact_number,uc.temp_contact_number FROM public.user u
INNER JOIN user_info ui ON ui.user_lid = u.id
INNER JOIN user_gender gd ON gd.id = ui.gender_lid
INNER JOIN resume r ON r.user_lid = u.id
INNER JOIN user_address ua ON ua.user_lid = u.id
INNER JOIN user_contact uc ON uc.user_lid = u.id
WHERE
r.id = CAST(input_id AS INT) AND
u.active = TRUE AND 
ui.active = TRUE AND 
ua.active = TRUE AND 
uc.active = TRUE) t);

RETURN output_result;
END
$$;
 :   DROP FUNCTION public.get_personal_details(input_id text);
       public          postgres    false            "           1255    87012    get_proforma_details(text)    FUNCTION       CREATE FUNCTION public.get_proforma_details(input_data text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
input_jsonb JSONB := input_data;
output_result JSONB :='{}';

BEGIN

DROP TABLE IF EXISTS temp_data;
CREATE TEMPORARY TABLE temp_data (
	id serial,
	level int,
	organization_lid VARCHAR
);

INSERT INTO temp_data(level,organization_lid)
SELECT CAST(t ->> 'level' AS INT),
	        t ->> 'organization_lid' 
FROM jsonb_array_elements(input_jsonb['proforma_details']) AS t;

IF(SELECT level FROM temp_data) IN(1,2) THEN

	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid)
	FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
	TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours,pd.status_lid, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
	pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid AND pd.status_lid IN (1,3)
	AND pd.level = (SELECT level FROM temp_data) AND pd.active = TRUE AND ua.organization_lid In (SELECT organization_lid FROM temp_data)
	ORDER BY pd.created_date) t1 
INNER JOIN 
	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

 ELSIF (SELECT level FROM temp_data) = 3 THEN
 
	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.level = (SELECT level FROM temp_data) AND pd.status_lid = 1
	AND ua.organization_lid In (SELECT organization_lid FROM temp_data) AND pd.active = TRUE ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

ELSE 

    output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid AND pd.status_lid IN (1)
	AND pd.level = (SELECT level FROM temp_data)  AND ua.organization_lid In (SELECT organization_lid FROM temp_data) AND pd.active = TRUE ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;
	
END IF;
RETURN output_result;
END
$$;
 <   DROP FUNCTION public.get_proforma_details(input_data text);
       public          postgres    false            #           1255    90790 !   get_proforma_details_report(text)    FUNCTION     ?  CREATE FUNCTION public.get_proforma_details_report(input_data text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
input_jsonb JSONB := input_data;
output_result JSONB :='{}';

BEGIN

DROP TABLE IF EXISTS temp_data;
CREATE TEMPORARY TABLE temp_data (
	id serial,
	level int,
	organization_lid VARCHAR
);

INSERT INTO temp_data(level,organization_lid)
SELECT CAST(t ->> 'level' AS INT),
	        t ->> 'organization_lid' 
FROM jsonb_array_elements(input_jsonb['proforma_details']) AS t;

-- IF(SELECT level FROM temp_data) IN(1,2) THEN

	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid)
	FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
	TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date, pd.status_lid, pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
	pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > (SELECT level FROM temp_data) and status_lid IN(1,2,3,4) OR pd.level = (SELECT level FROM temp_data) AND status_lid IN (2,4))
    AND ua.organization_lid = (SELECT organization_lid FROM temp_data) AND pd.active = TRUE 
	ORDER BY pd.created_date) t1 
INNER JOIN 
	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

--  ELSIF (SELECT level FROM temp_data) = 3 THEN
 
-- 	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
--     TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
--     pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
-- 	FROM proforma_details pd 
-- 	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
-- 	INNER JOIN application_status ap on ap.id = pd.status_lid 
-- 	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid AND pd.status_lid IN (1,2,3)
-- 	WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level IN(4,5,6) AND status_lid IN (1,2))
-- 	AND pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > 3 AND status_lid IN (1,2))
-- 	AND ua.organization_lid In (SELECT organization_lid FROM temp_data) AND pd.active = TRUE ORDER BY pd.created_date) t1 
-- 	INNER JOIN 

-- 	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
-- 	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
-- 	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
-- 	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
-- 	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
-- 	ON t2.application_lid = t1.application_lid ) t3 ) ;

-- ELSE 

--     output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
--     TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
--     pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
-- 	FROM proforma_details pd 
-- 	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
-- 	INNER JOIN application_status ap on ap.id = pd.status_lid 
-- 	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid
-- 	WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > (SELECT level FROM temp_data) AND status_lid IN(1,2,3))
-- 	OR pd.proforma_id IN (SELECT proforma_id FROM proforma_details WHERE level = (SELECT level FROM temp_data) AND status_lid IN(2)) AND ua.organization_lid In (SELECT organization_lid FROM temp_data)  AND pd.active = TRUE ORDER BY pd.created_date) t1 
-- 	INNER JOIN 

-- 	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
-- 	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
-- 	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
-- 	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
-- 	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
-- 	ON t2.application_lid = t1.application_lid ) t3 ) ;
	
-- END IF;
RETURN output_result;
END
$$;
 C   DROP FUNCTION public.get_proforma_details_report(input_data text);
       public          postgres    false                        1255    87013    get_proforma_report(text)    FUNCTION     ?  CREATE FUNCTION public.get_proforma_report(input_data text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
input_jsonb JSONB := input_data;
output_result JSONB :='{}';

BEGIN

DROP TABLE IF EXISTS temp_data;
CREATE TEMPORARY TABLE temp_data (
	id serial,
	level int,
	organization_lid VARCHAR
);

INSERT INTO temp_data(level,organization_lid)
SELECT CAST(t ->> 'level' AS INT),
	        t ->> 'organization_lid' 
FROM jsonb_array_elements(input_jsonb['proforma_details']) AS t;

output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
pd.aol_obe, pd.level,pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
FROM proforma_details pd 
INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
INNER JOIN application_status ap on ap.id = pd.status_lid 
INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid AND pd.status_lid IN (1,2,3,4) 
AND pd.level > (SELECT level FROM temp_data) AND ua.organization_lid in (SELECT organization_lid FROM temp_data)
ORDER BY pd.created_date) t1 
INNER JOIN 

(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
INNER JOIN experience_type et ON et.id = ar.experience_type_lid
GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
ON t2.application_lid = t1.application_lid ) t3 ) ;

RETURN output_result;
END
$$;
 ;   DROP FUNCTION public.get_proforma_report(input_data text);
       public          postgres    false            '           1255    104575    get_rejected_proforma()    FUNCTION     ?  CREATE FUNCTION public.get_rejected_proforma() RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE

output_result JSONB := '{}';

BEGIN
 
	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.status_lid,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,pd.modified_by
    ,pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
    WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level IN(4,5,6) AND status_lid = 2)
	OR pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level = 3 AND status_lid = 4) AND pd.active = TRUE	ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;
	
RETURN output_result;
END
$$;
 .   DROP FUNCTION public.get_rejected_proforma();
       public          postgres    false            ?           1255    87014    get_resume_achievement(text)    FUNCTION     ?  CREATE FUNCTION public.get_resume_achievement(input_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result JSONB :='{}';
BEGIN

output_result['resume_achievement'] :=
(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT ot.name,ra.resume_achievement_lid,ra.achievement_type_lid,ra.title,ra.description,
ra.organization_name,ra.organization_type_lid,ra.url_path,ra.achievement_date,ra.duration
from resume_achievement ra 
INNER JOIN resume r ON r.id = ra.resume_lid
INNER JOIN achievement_type att ON att.id = ra.achievement_type_lid
INNER JOIN organization_type ot ON ot.id = ra.organization_type_lid
WHERE r.id = CAST(input_id AS INT) AND ra.achievement_type_lid = 2 AND ra.active = TRUE AND att.active = true)t);
RETURN output_result;
END
$$;
 <   DROP FUNCTION public.get_resume_achievement(input_id text);
       public          postgres    false            ?           1255    87015    get_resume_experience(text)    FUNCTION     ?  CREATE FUNCTION public.get_resume_experience(input_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result JSONB :='{}';
BEGIN

output_result['resume_experience'] := (SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT et.abbr,re.resume_experience_lid,re.experience_type_lid,re.employer_name,
re.designation,re.designation_lid,re.description,re.start_date,re.end_date,re.responsibilities,re.is_current,re.duration,re.subject_taught
FROM resume_experience  re
INNER JOIN resume r ON r.id = re.resume_lid
INNER JOIN experience_type et ON et.id = re.experience_type_lid																	 
WHERE r.id = CAST(input_id AS INT) AND re.active = true) t);

RETURN output_result;
END
$$;
 ;   DROP FUNCTION public.get_resume_experience(input_id text);
       public          postgres    false            ?           1255    87016    get_resume_publication(text)    FUNCTION     }  CREATE FUNCTION public.get_resume_publication(input_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result JSONB :='{}';
BEGIN

output_result['resume_publication'] :=(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT rp.resume_achievement_lid,rp.publication_role,rp.no_of_authors,rp.publisher,ra.title,rp.year_of_publication,rp.publication_url_path
FROM resume_publication rp
INNER JOIN resume_achievement ra ON ra.resume_achievement_lid = rp.resume_achievement_lid
INNER JOIN resume r ON r.id = ra.resume_lid
WHERE r.id =CAST(input_id AS INT) AND rp.active = TRUE AND ra.active = true)t);
RETURN output_result;
END
$$;
 <   DROP FUNCTION public.get_resume_publication(input_id text);
       public          postgres    false            ?           1255    87017    get_resume_qualification(text)    FUNCTION     ?  CREATE FUNCTION public.get_resume_qualification(input_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result JSONB :='{}';

BEGIN

output_result['resume_qualification'] :=(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT qt.abbr,rq.resume_qualification_lid,rq.qualification_type_lid,rq.topic_of_study,rq.resume_lid,
rq.university,rq.institute,rq.percentile,rq.year_of_passing,rq.url_path FROM resume_qualification rq
INNER JOIN resume r ON r.id = rq.resume_lid
INNER JOIN qualification_type qt ON qt.id = rq.qualification_type_lid
WHERE r.id = CAST(input_id AS INT) AND rq.active = true)t);

RETURN output_result;
END
$$;
 >   DROP FUNCTION public.get_resume_qualification(input_id text);
       public          postgres    false            ?           1255    87018    get_resume_research(text)    FUNCTION     S  CREATE FUNCTION public.get_resume_research(input_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result JSONB :='{}';

BEGIN

output_result['resume_research'] :=(SELECT jsonb_agg(to_jsonb(t.*))FROM (SELECT rr.resume_achievement_lid,ra.title,rr.volume_year,ra.description,rr.category,rr.research_url_path
FROM resume_research rr
INNER JOIN resume_achievement ra ON ra.resume_achievement_lid = rr.resume_achievement_lid
INNER JOIN resume r ON r.id = ra.resume_lid
WHERE r.id = CAST(input_id AS INT) AND rr.active = TRUE AND ra.active = TRUE)t);
RETURN output_result;
END
$$;
 9   DROP FUNCTION public.get_resume_research(input_id text);
       public          postgres    false            ?           1255    87019    get_resume_skill_selected(text)    FUNCTION       CREATE FUNCTION public.get_resume_skill_selected(input_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result JSONB :='{}';

BEGIN

output_result['resume_skill_selected'] :=(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT rs.resume_skill_selected_lid,rs.skill_lid,sk.skill_name,rs.resume_lid
FROM resume_skill_selected rs
INNER JOIN resume r ON r.id = rs.resume_lid
INNER JOIN skill sk ON sk.id = rs.skill_lid
WHERE r.id = CAST(input_id AS INT) AND sk.active = TRUE AND rs.active = true)t);

RETURN output_result;
END
$$;
 ?   DROP FUNCTION public.get_resume_skill_selected(input_id text);
       public          postgres    false            ?           1255    87020    get_status_list(text)    FUNCTION     E  CREATE FUNCTION public.get_status_list(input_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

	DECLARE
	input_jsonb JSONB := input_id;
	output_result JSONB :='{}';
    
	BEGIN

	DROP TABLE IF EXISTS temp_proforma_status;
	CREATE TEMPORARY TABLE temp_proforma_status(
	id serial,
	proforma_lid int,
	level int NOT NULL
	);

	INSERT INTO temp_proforma_status(proforma_lid,level)
	SELECT CAST(t ->> 'proforma_lid' AS int) "proforma_lid",
		   CAST(t ->> 'level' AS int ) "level"
	FROM jsonb_array_elements(input_jsonb['get_status_list']) AS t;	

			
	  IF(SELECT level FROM temp_proforma_status) = 3 THEN
			
			IF(SELECT status_lid FROM proforma_details WHERE proforma_id =(SELECT proforma_lid FROM temp_proforma_status)) != 2 THEN
			
			output_result['status_list'] := (SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT id,name FROM application_status WHERE id IN (1,2,3) AND (SELECT status_lid FROM proforma_details WHERE proforma_id = (SELECT proforma_lid FROM temp_proforma_status)) != 2 )t); 
			END IF;
			
		    IF (SELECT status_lid FROM proforma_details WHERE proforma_id =(SELECT proforma_lid FROM temp_proforma_status)) = 2 AND
			(SELECT level FROM proforma_details WHERE proforma_id = (SELECT proforma_lid FROM temp_proforma_status)) IN (4,5,6) THEN
			
			output_result['status_list'] := (SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT id,name FROM application_status WHERE id = 4)t);
			
			END IF;
		ELSE 
		
		  output_result['status_list'] :=  (SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT id,name FROM application_status WHERE id IN (1,2))t);

		END IF;		
	
RETURN output_result;
END
$$;
 5   DROP FUNCTION public.get_status_list(input_id text);
       public          postgres    false            ?           1255    87021    get_user_resume_details(text)    FUNCTION       CREATE FUNCTION public.get_user_resume_details(input_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result JSONB :='{}';

BEGIN
output_result ['discontinue_status'] := (SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT apf.*,pd.module,pd.program_name FROM approved_faculty_status apf
										INNER JOIN proforma_details pd ON pd.proforma_id = apf.proforma_lid INNER JOIN 
										user_application ua ON ua.appln_id = pd.application_lid INNER JOIN 
										resume r ON r.id = ua.resume_lid AND r.id =  CAST(input_id AS INT) AND ua.resume_lid =  CAST(input_id AS INT)) t);


output_result ['personal_details'] :=(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT u.id, u.user_id, ua.address,ua.address_type_lid,ua.city,ua.pin_code,ui.email,ui.f_name,ui.l_name,
ui.date_of_birth,ui.pancard_no,ui.aadhar_card_no,ui.temp_email,ui.profile_url_path,ui.gender_lid,gd.name,ui.pancard_url_path,
ui.aadhar_card_url_path,ui.nationality,uc.contact_number,uc.temp_contact_number FROM public.user u
INNER JOIN user_info ui ON ui.user_lid = u.id
INNER JOIN user_gender gd ON gd.id = ui.gender_lid
INNER JOIN resume r ON r.user_lid = u.id
INNER JOIN user_address ua ON ua.user_lid = u.id
INNER JOIN user_contact uc ON uc.user_lid = u.id
WHERE
r.id = CAST(input_id AS INT) AND
u.active = TRUE AND 
ui.active = TRUE AND 
ua.active = TRUE AND 
uc.active = TRUE) t);

output_result['resume_qualification'] :=(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT qt.abbr,qt.name,rq.is_completed,rq.resume_qualification_lid,rq.qualification_type_lid,rq.topic_of_study,
rq.university,rq.institute,rq.percentile,rq.year_of_passing,rq.url_path FROM resume_qualification rq
INNER JOIN resume r ON r.id = rq.resume_lid
INNER JOIN qualification_type qt ON qt.id = rq.qualification_type_lid
WHERE r.id = CAST(input_id AS INT) AND rq.active = true)t);

output_result['resume_experience'] := (SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT  re.padagogy,et.abbr,re.resume_experience_lid,re.experience_type_lid,re.employer_name,
re.designation,re.designation_lid,re.description,re.start_date,re.end_date,re.responsibilities,re.is_current,re.duration
FROM resume_experience  re
INNER JOIN resume r ON r.id = re.resume_lid
INNER JOIN experience_type et on et.id = re.experience_type_lid																	 
WHERE r.id = CAST(input_id AS INT) AND re.active = true) t);

output_result['resume_skill_selected'] :=(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT sk.skill_type_lid,rs.resume_skill_selected_lid,rs.skill_lid,sk.skill_name,rs.resume_lid
FROM resume_skill_selected rs
INNER JOIN resume r ON r.id = rs.resume_lid
INNER JOIN skill sk ON sk.id = rs.skill_lid
WHERE r.id = CAST(input_id AS INT) AND sk.active = TRUE AND rs.active = true)t);

output_result['resume_achievement'] :=
(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT ot.name,ra.resume_achievement_lid,ra.achievement_type_lid,ra.title,ra.description,
ra.organization_name,ra.organization_type_lid,ra.url_path,ra.achievement_date,ra.duration
FROM resume_achievement ra 
INNER JOIN resume r ON r.id = ra.resume_lid
INNER JOIN achievement_type att ON att.id = ra.achievement_type_lid
INNER JOIN organization_type ot ON ot.id = ra.organization_type_lid
WHERE r.id = CAST(input_id AS INT) AND ra.achievement_type_lid = 2 AND ra.active = TRUE AND att.active = true)t);

output_result['resume_publication'] :=(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT rp.resume_achievement_lid,rp.publication_role,rp.no_of_authors,rp.publisher,ra.title,rp.year_of_publication,rp.publication_url_path
FROM resume_publication rp
INNER JOIN resume_achievement ra ON ra.resume_achievement_lid = rp.resume_achievement_lid
INNER JOIN resume r ON r.id = ra.resume_lid
WHERE r.id =CAST(input_id AS INT) AND rp.active = TRUE AND ra.active = true)t);

output_result['resume_research'] :=(SELECT jsonb_agg(to_jsonb(t.*))FROM (SELECT rr.resume_achievement_lid,ra.title,rr.volume_year,ra.description,rr.category,rr.research_url_path
FROM resume_research rr
INNER JOIN resume_achievement ra ON ra.resume_achievement_lid = rr.resume_achievement_lid
INNER JOIN resume r ON r.id = ra.resume_lid
WHERE r.id = CAST(input_id AS INT) AND rr.active = TRUE AND ra.active = TRUE)t);

output_result['bank_details'] :=
(SELECT to_jsonb(t.*) FROM (SELECT bc.abbr,bd.user_lid,bd.bank_account_type_lid,bc.account_type,bd.bank_name,bd.branch_name,
bd.ifsc_code,bd.micr_code,bd.account_number,bd.url_path
FROM bank_details bd
INNER JOIN resume r ON r.user_lid = bd.user_lid
INNER JOIN bank_account_type bc ON bc.id = bd.bank_account_type_lid
WHERE r.id = CAST(input_id AS INT) AND bd.active = TRUE AND bc.active = TRUE)t);
RETURN output_result;
END
$$;
 =   DROP FUNCTION public.get_user_resume_details(input_id text);
       public          postgres    false            ?           1255    87022    iif(boolean, text, text)    FUNCTION     ?   CREATE FUNCTION public.iif(condition boolean, true_result text, false_result text) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF condition THEN
    RETURN true_result;
 ELSE
    RETURN false_result;
 END IF;
END
$$;
 R   DROP FUNCTION public.iif(condition boolean, true_result text, false_result text);
       public          postgres    false                        1255    87023    insert_achievement(text)    FUNCTION     ?  CREATE FUNCTION public.insert_achievement(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE 
      output_result JSONB;
      input_jsonb jsonb := input_json;
	  output_json JSONB;
	  
 BEGIN
  
  DROP TABLE IF EXISTS temp_achievement;
  CREATE TABLE temp_achievement
	(  id serial,
	   resume_lid int,
	   achievement_type_lid int,
	   organization_name varchar(500) ,
	   title varchar(100) not null,
	   organization_type_lid int,
	   achievement_date date ,
	   description varchar(100),
	   url_path varchar(500),
	   duration varchar(100)
	   );
	   
	INSERT INTO temp_achievement( resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration)
	SELECT CAST(t ->> 'resume_lid' AS integer) "resume_lid",
		   CAST(t ->> 'achievement_type_lid' AS integer) AS "achievement_type_lid",
		        t ->> 'title' AS "title",
				t ->> 'description' AS "description",
		        t ->> 'organization_name' AS "organization_name",				
		   CAST(t ->> 'organization_type_lid' AS integer) AS "organization_type_lid",
		    	t ->> 'url_path' AS "url_path",
		   CAST(t ->> 'achievement_date' AS date) AS "achievement_date",				
				t ->> 'duration' AS "duration"
	FROM jsonb_array_elements(input_jsonb['insert_award']) AS t;
	
     with inserted_id AS(	 
	     INSERT INTO resume_achievement(resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration)
		 SELECT resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration from temp_achievement
         RETURNING resume_achievement_lid
        )
	    SELECT  INTO output_json json_agg(json_build_object('resume_achievement_lid',resume_achievement_lid)) from inserted_id;	 
	
    output_result := '{"status":200, "message":"Successfull"}';
	output_result['data'] := output_json;
	
	RETURN  output_result;

		
END;	
$$;
 :   DROP FUNCTION public.insert_achievement(input_json text);
       public          postgres    false                       1255    87024    insert_application(text)    FUNCTION     o  CREATE FUNCTION public.insert_application(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE 
      input_jsonb jsonb := input_json;
						  
 BEGIN
  
 DROP TABLE IF EXISTS temp_application;
 CREATE TABLE temp_application(
  id serial,
  resume_lid int not null,
  organization_lid varchar not null,
  active boolean default(true) not null
 );
 	   
	 DROP TABLE IF EXISTS ids;
	 CREATE TEMPORARY TABLE ids(
	 id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	 appln_id int 
	 );
 
 INSERT INTO temp_application(resume_lid,organization_lid)
 SELECT cast(t ->> 'resume_lid' AS int) AS "resume_lid",
	         t ->> 'organization_lid' AS "organization_lid"
 FROM jsonb_array_elements(input_jsonb['create_job_application']) AS t;
 

	 with last_ids AS(
	 INSERT INTO user_application(resume_lid,organization_lid)
	 SELECT resume_lid,organization_lid from temp_application
	 RETURNING appln_id
	 )
	 INSERT INTO ids(appln_id)
	SELECT appln_id FROM last_ids;

	
INSERT INTO application_user_info (user_lid,email,f_name,l_name,date_of_birth,pancard_no,aadhar_card_no,temp_email,gender_lid,pancard_url_path, profile_url_path,aadhar_card_url_path,nationality,resume_lid,application_lid)
SELECT user_lid,email,f_name,l_name,date_of_birth,pancard_no,aadhar_card_no,temp_email,gender_lid,pancard_url_path, profile_url_path,aadhar_card_url_path,nationality,resume_lid,(select appln_id from ids) from user_info
WHERE user_info.resume_lid = (SELECT resume_lid FROM temp_application);
 
INSERT INTO application_user_address(user_lid, address, address_type_lid,city,pin_code,resume_lid,application_lid)
SELECT user_lid, address, address_type_lid,city,pin_code,resume_lid,(SELECT appln_id FROM ids) FROM user_address
WHERE user_address.resume_lid = (SELECT resume_lid FROM temp_application);

INSERT INTO application_user_contact(user_lid,contact_number,temp_contact_number,resume_lid,application_lid)
SELECT user_lid ,contact_number,temp_contact_number,resume_lid,(SELECT appln_id FROM ids) FROM user_contact
WHERE user_contact.resume_lid = (SELECT resume_lid FROM temp_application);

INSERT INTO application_resume_qualification(resume_qualification_lid,resume_lid,qualification_type_lid,topic_of_study,university,institute,percentile,year_of_passing,url_path, is_completed,application_lid)	 
SELECT resume_qualification_lid,resume_lid,qualification_type_lid,topic_of_study,university,institute,percentile,year_of_passing,url_path, is_completed,(select appln_id from ids) from resume_qualification
WHERE resume_qualification.resume_lid = (SELECT resume_lid FROM temp_application);

INSERT INTO application_resume_experience(resume_experience_lid,resume_lid,experience_type_lid,employer_name,designation,designation_lid,description,start_date,end_date,responsibilities,is_current,duration,padagogy,application_lid)
SELECT resume_experience_lid,resume_lid,experience_type_lid,employer_name,designation,designation_lid,description,start_date,end_date,responsibilities,is_current,duration,padagogy,(select appln_id from ids) from resume_experience
WHERE resume_experience.resume_lid = (SELECT resume_lid FROM temp_application);

INSERT INTO application_resume_skill_selected(resume_skill_selected_lid,resume_lid,skill_lid,application_lid)
SELECT resume_skill_selected_lid,resume_lid,skill_lid,(SELECT appln_id FROM ids)  FROM resume_skill_selected
WHERE resume_skill_selected.resume_lid = (SELECT resume_lid FROM temp_application);

INSERT INTO application_resume_achievement(resume_achievement_lid,resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration,application_lid)
SELECT resume_achievement_lid,resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration,(select appln_id from ids) from resume_achievement 
WHERE resume_achievement.resume_lid = (SELECT resume_lid FROM temp_application);
 
INSERT INTO application_resume_publication(resume_publication_lid,resume_achievement_lid,publication_role,no_of_authors,publisher,year_of_publication,publication_url_path,application_lid)
SELECT rp.resume_publication_lid,rp.resume_achievement_lid,rp.publication_role,rp.no_of_authors,rp.publisher,rp.year_of_publication,rp.publication_url_path,(select appln_id from ids)
FROM resume_publication rp INNER JOIN resume_achievement ra ON rp.resume_achievement_lid = ra.resume_achievement_lid
AND ra.resume_lid = (SELECT resume_lid FROM temp_application) AND ra.achievement_type_lid = 1;

INSERT INTO application_resume_research(resume_research_lid,resume_achievement_lid,volume_year,category,description,research_url_path,application_lid)
SELECT rr.resume_research_lid,rr.resume_achievement_lid,rr.volume_year,rr.category,rr.description,rr.research_url_path,(select appln_id from ids)
FROM resume_research rr inner join resume_achievement ra on rr.resume_achievement_lid = ra.resume_achievement_lid
AND ra.resume_lid = (select resume_lid from temp_application) AND ra.achievement_type_lid = 3;

INSERT INTO application_bank_details(user_lid,bank_account_type_lid,resume_lid,bank_name,branch_name,ifsc_code,micr_code,account_number,url_path,application_lid)	 
SELECT user_lid,bank_account_type_lid,resume_lid,bank_name,branch_name,ifsc_code,micr_code,account_number,url_path,(SELECT appln_id FROM ids) FROM bank_details
WHERE bank_details.resume_lid = (SELECT resume_lid FROM temp_application);

 RETURN '{"status": 200, "message": "Successfull."}';

END
$$;
 :   DROP FUNCTION public.insert_application(input_json text);
       public          postgres    false                       1255    87025    insert_bank_details(text)    FUNCTION     ]  CREATE FUNCTION public.insert_bank_details(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
	
DECLARE
    output_result JSONB;
	input_jsonb JSONB := input_json;
	output_json JSONB;
    
BEGIN

   DROP TABLE IF EXISTS temp_bank_details;
   CREATE TEMPORARY TABLE temp_bank_details (
    id serial,
    user_lid int not null,
	bank_account_type_lid int not null ,
	resume_lid int not null,
	bank_name varchar(100) not null,
	branch_name varchar(100) not null,
	ifsc_code varchar(100) not null,
	micr_code varchar(20),
	account_number varchar(100) not null,
	url_path varchar(100),
	active boolean DEFAULT(true) not null
 );
 
 INSERT INTO temp_bank_details(user_lid,bank_account_type_lid,resume_lid,bank_name,branch_name,ifsc_code,micr_code,account_number, url_path)
 SELECT  cast(t ->> 'user_lid' AS integer) AS "user_lid",
        cast(t ->> 'bank_account_type_lid' AS integer) AS "bank_account_type_lid",
		cast(t ->> 'resume_lid' AS int) AS "resume_lid",
		 t ->> 'bank_name' AS "bank_name",
		 t ->> 'branch_name' AS "branch_name",
		 t ->> 'ifsc_code'  AS "ifsc_code",
		 t ->> 'micr_code'  AS "micr_code",
		 t ->> 'account_number' AS "account_number",
		 t ->> 'url_path' AS "url_path"
 FROM jsonb_array_elements(input_jsonb['insert_bank_data']) AS t;
		 
		 

	    INSERT INTO bank_details(user_lid,bank_account_type_lid,resume_lid,bank_name,branch_name,ifsc_code,micr_code,account_number,url_path)	 
	    SELECT user_lid,bank_account_type_lid,resume_lid,bank_name,branch_name,ifsc_code,micr_code,account_number,url_path FROM temp_bank_details;
	
RETURN '{"status":200, "message":"Successfull"}';
	
END;	
$$;
 ;   DROP FUNCTION public.insert_bank_details(input_json text);
       public          postgres    false                       1255    87026    insert_campus_data(text)    FUNCTION     ;  CREATE FUNCTION public.insert_campus_data(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
	
DECLARE 
	input_jsonb JSONB := input_json;
	
BEGIN
  
   DROP TABLE IF EXISTS temp_campus;
   CREATE TEMPORARY TABLE temp_campus (
     id serial,
	 campus_id varchar(100),
	 abbr varchar(100),
	 name varchar(255),
	 description varchar(250) 
	 ); 
	   
    INSERT INTO temp_campus(campus_id,abbr,name,description)
    SELECT 
		 t ->> 'campus_id' AS "campus_id",
		 t ->> 'abbr' AS "abbr",
		 t ->> 'name'  AS "name",
	   	 t ->> 'description' AS "description"
	FROM jsonb_array_elements(input_jsonb['campus_data']) AS t;
		 
		 
		INSERT INTO  campus (campus_id,abbr,name,description)
	    SELECT campus_id,abbr,name,description from temp_campus;

	   RETURN '{"status":200, "message":"Successfull"}';
	   
	
END;	
$$;
 :   DROP FUNCTION public.insert_campus_data(input_json text);
       public          postgres    false                       1255    87027    insert_job_application(text)    FUNCTION     \  CREATE FUNCTION public.insert_job_application(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE 
     
      input_jsonb jsonb := input_json;

BEGIN
 
 DROP TABLE IF EXISTS temp_application;
 CREATE TABLE temp_application(
   id serial,
   resume_lid int not null,
   organization_lid VARCHAR(100) not null,
   active boolean default(true) not null
   );
 
 	   
 DROP TABLE IF EXISTS ids;
 CREATE TEMPORARY TABLE ids(
	id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	appln_id int 
	 );
	
 
 INSERT INTO temp_application(resume_lid,organization_lid)
 SELECT 
       CAST(t ->> 'resume_lid' AS int) AS "resume_lid",
	        t ->> 'organization_lid' AS "organization_lid"
 FROM jsonb_array_elements(input_jsonb['create_job_application']) AS t;
 
 with last_ids AS(
	 INSERT INTO user_application(resume_lid,organization_lid)
	 SELECT resume_lid,organization_lid from temp_application
	 RETURNING appln_id
	 )
	 INSERT INTO ids(appln_id)
	SELECT  appln_id FROM last_ids;
	
	UPDATE application_resume_qualification set application_lid = (select appln_id from ids) where rev_timestamp = (select rev_timestamp from application_resume_qualification WHERE application_resume_qualification.resume_lid = (select resume_lid from temp_application) order by rev_timestamp desc limit 1);
    
	UPDATE application_resume_achievement set application_lid = (select appln_id from ids) where rev_timestamp = (select rev_timestamp from  application_resume_achievement WHERE application_resume_achievement.resume_lid = (select resume_lid from temp_application) AND achievement_type_lid = 2 order by rev_timestamp desc limit 1);
    
	UPDATE application_resume_skill_selected set application_lid = (select appln_id from ids) where rev_timestamp = (select rev_timestamp from  application_resume_skill_selected WHERE application_resume_skill_selected.resume_lid = (select resume_lid from temp_application) order by  rev_timestamp desc limit 1);
    
	UPDATE application_resume_achievement set application_lid = (select appln_id from ids) where rev_timestamp = (select rev_timestamp from  application_resume_achievement WHERE application_resume_achievement.resume_lid = (select resume_lid from temp_application) AND achievement_type_lid = 1 order by rev_timestamp desc limit 1);
    
	UPDATE application_resume_achievement set application_lid = (select appln_id from ids) where rev_timestamp = (select rev_timestamp from  application_resume_achievement WHERE application_resume_achievement.resume_lid = (select resume_lid from temp_application) AND achievement_type_lid = 3 order by rev_timestamp desc limit 1);
    
	UPDATE application_resume_achievement set application_lid = (select appln_id from ids) where rev_timestamp = (select rev_timestamp from  application_resume_achievement WHERE application_resume_achievement.resume_lid = (select resume_lid from temp_application) AND achievement_type_lid = 4 order by rev_timestamp desc limit 1);
    
	UPDATE application_resume_experience set  application_lid = (select appln_id from ids) where rev_timestamp = (select rev_timestamp from application_resume_experience WHERE application_resume_experience.resume_lid = (select resume_lid from temp_application) order by rev_timestamp desc limit 1);
    
	UPDATE application_user_info set application_lid = (select appln_id from ids) where rev_timestamp = (select rev_timestamp from application_user_info WHERE application_user_info.resume_lid = (select resume_lid from temp_application) order by rev_timestamp desc limit 1);
    
	UPDATE application_user_address set application_lid = (select appln_id from ids) where rev_timestamp = (select rev_timestamp from  application_user_address WHERE application_user_address.resume_lid = (select resume_lid from temp_application) order by rev_timestamp desc limit 1);
    
	UPDATE application_user_contact set application_lid = (select appln_id from ids) where rev_timestamp = (select rev_timestamp from application_user_contact WHERE application_user_contact.resume_lid = (select resume_lid from temp_application) order by rev_timestamp desc limit 1);
    
	UPDATE application_bank_details set application_lid = (select appln_id from ids) where rev_timestamp = (select rev_timestamp from application_bank_details WHERE application_bank_details.resume_lid = (select resume_lid from temp_application) order by rev_timestamp desc limit 1);
	
	 RETURN '{"status": 200, "message": "Successfull."}';
	END;
$$;
 >   DROP FUNCTION public.insert_job_application(input_json text);
       public          postgres    false                       1255    87028    insert_organization_data(text)    FUNCTION     ?  CREATE FUNCTION public.insert_organization_data(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
	
DECLARE 
	input_jsonb JSONB := input_json;
	
BEGIN
  
  DROP TABLE IF EXISTS temp_organization;
   CREATE TEMPORARY TABLE temp_organization (
    id serial,
	organization_id varchar(255),
	name varchar(255)
	   
	); 
	

	INSERT INTO temp_organization(organization_id,name)
    SELECT  
		  cast(t ->> 'organization_id' AS int) AS  "organization_id",
		  t ->> 'name'  AS "name"
	   FROM jsonb_array_elements(input_jsonb['organization_data']) AS t;
		 
		 
	INSERT INTO  organization (organization_id,name)
	SELECT organization_id,name FROM temp_organization;

	   RETURN '{"status":200, "message":"Successfull"}';
	   
	
END;	
$$;
 @   DROP FUNCTION public.insert_organization_data(input_json text);
       public          postgres    false                       1255    87029    insert_proforma_details(text)    FUNCTION       CREATE FUNCTION public.insert_proforma_details(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$

-- DO $$
declare

input_jsonb jsonb := input_json;
-- input_json JSONB :='{"insert_proforma":[
--   {
--     "application_lid": "119",
--     "module": "maths",
--     "teaching_hours": "3",
--     "program_id": "1111",
--     "acad_session": "semester-2",
--     "commencement_date_of_program": "2013-03-31",
--     "rate_per_hours": "300",
--     "total_no_of_hrs_alloted": "30",
--     "no_of_division": "3",
--     "student_count_per_division": "3000",
--     "aol_obe": "OBL"
--   }
-- ]}';
  
BEGIN

drop table if exists temp_proforma_details;
create TEMPORARY table temp_proforma_details(
id serial,
application_lid int not null,
module varchar,
teaching_hours varchar(50),
program_id int not null,
acad_session varchar(100),
commencement_date_of_program date,
rate_per_hours int,
total_no_of_hrs_alloted int,
no_of_division int,
student_count_per_division int,
aol_obe varchar,
created_by varchar(100),
created_date timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
level int,
status_lid int,
last_modified_date timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
active boolean  not null default(true)
);

insert into temp_proforma_details(application_lid,module,teaching_hours,program_id,acad_session,commencement_date_of_program,rate_per_hours,total_no_of_hrs_alloted,no_of_division,student_count_per_division,aol_obe,level,status_lid)
select cast(t ->> 'application_lid' AS int) "application_lid",
           t ->> 'module' AS  "module",
	        t ->> 'teaching_hours' AS "teaching_hours",
	   cast(t ->> 'program_id' AS int ) "program_id",
	        t ->> 'acad_session' AS "acad_session",
	   cast(t ->> 'commencement_date_of_program' AS date ) "commencement_date_of_program",
	   cast(t ->> 'rate_per_hours' AS int ) "rate_per_hours",
	   cast(t ->> 'total_no_of_hrs_alloted' AS int ) "total_no_of_hrs_alloted",
	   cast(t ->> 'no_of_division' AS int ) "no_of_division",
	   cast(t ->> 'student_count_per_division' AS int ) "student_count_per_division",
            t ->> 'aol_obe' AS "aol_obe",
	   cast(t ->> 'level' AS int ) "level",
	   cast(t ->> 'status_lid' AS int ) "status_lid"
from jsonb_array_elements(input_jsonb['insert_proforma']) AS t;
	
	insert into proforma_details(application_lid,module,teaching_hours,program_id,acad_session,commencement_date_of_program,rate_per_hours,total_no_of_hrs_alloted,no_of_division,student_count_per_division,aol_obe,level,status_lid)
	select application_lid,module,teaching_hours,program_id,acad_session,commencement_date_of_program,rate_per_hours,total_no_of_hrs_alloted,no_of_division,student_count_per_division,aol_obe,level,status_lid from  temp_proforma_details;
	
	 RETURN '{"status":200, "message":"Successfull"}';
	
	END;	
 
$_$;
 ?   DROP FUNCTION public.insert_proforma_details(input_json text);
       public          postgres    false                       1255    87030    insert_publication(text)    FUNCTION     (  CREATE FUNCTION public.insert_publication(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE 
      output_result JSONB;
      input_jsonb jsonb := input_json;
	  output_json JSONB;
 BEGIN
  
  drop table if exists temp_publication_exp;
  create table temp_publication_exp
	(  id serial,
	   resume_lid int,
	   achievement_type_lid int,
	   organization_name varchar(500) ,
	   title varchar(100) not null,
	   organization_type_lid int,
	   achievement_date date ,
	   description varchar(100),
	   url_path varchar(500),
	   duration varchar(100),
	   publication_role varchar(100),
	   no_of_authors varchar(100),
	   publisher varchar(100),
	   year_of_publication varchar(200),
	   publication_url_path varchar(255));
	  
	 drop table if exists ids;
	 create temporary table ids(
	 id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	 resume_achievement_lid int 
	 );
	
	insert into temp_publication_exp( resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration,publication_role,no_of_authors,publisher,year_of_publication,publication_url_path)
	select cast(t ->> 'resume_lid' AS integer) "resume_lid",
		   cast(t ->> 'achievement_type_lid' AS integer) AS "achievement_type_lid",
		        t ->> 'title' AS "title",
				t ->> 'description' AS "description",
		        t ->> 'organization_name' AS "organization_name",				
		   cast(t ->> 'organization_type_lid' AS integer) AS "organization_type_lid",
		    	t ->> 'url_path' AS "url_path",
		   cast(t ->> 'achievement_date' AS date) AS "achievement_date",				
				t ->> 'duration' AS "duration",
				t ->> 'publication_role' AS "role",
				t ->> 'no_of_authors' AS "no_of_authors",
				t ->> 'publisher' AS "publisher",
				t ->> 'year_of_publication' AS "year_of_publication",
				t ->> 'publication_url_path' AS "publication_url_path"
			
	from jsonb_array_elements(input_jsonb['insert_publication']) AS t;
	
	with last_ids AS(
	     insert into resume_achievement(resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration)
		 select resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration from temp_publication_exp
		 RETURNING resume_achievement_lid
		 )
		 insert into ids(resume_achievement_lid)
		 select resume_achievement_lid from last_ids;
		 
		  with inserted_id AS(
		 insert into resume_publication(resume_achievement_lid,publication_role,no_of_authors,publisher,year_of_publication,publication_url_path)
		 select ids.resume_achievement_lid,p.publication_role,p.no_of_authors,p.publisher,p.year_of_publication,p.publication_url_path
		 from temp_publication_exp p
		 inner join ids on ids.id = p.id
			  RETURNING resume_achievement_lid
			  )
		 select  into output_json json_agg(json_build_object('resume_achievement_lid',resume_achievement_lid)) from inserted_id;	 
		
	   output_result := '{"status":200, "message":"Successfull"}';
	   output_result['data'] := output_json;
	
	RETURN  output_result;
	END;
	
$$;
 :   DROP FUNCTION public.insert_publication(input_json text);
       public          postgres    false            	           1255    87031 "   insert_qualification_details(text)    FUNCTION     z  CREATE FUNCTION public.insert_qualification_details(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
	
DECLARE 
    output_result JSONB;
	input_jsonb JSONB := input_json;
	output_json JSONB;
BEGIN

   drop table if exists temp_qualification;
   create TEMPORARY table temp_qualification (
    id serial,
    resume_lid int not null,
	qualification_type_lid int ,
	topic_of_study varchar(100),
	university varchar(100),
	institute varchar(100),
	percentile numeric(6,3) ,
	year_of_passing varchar(100),
	url_path varchar(100) ,
	is_completed boolean
 );
 
 insert into temp_qualification(resume_lid,qualification_type_lid,topic_of_study,university,institute,percentile,year_of_passing,url_path, is_completed)
 select  cast(t ->> 'resume_lid' AS integer) AS "resume_lid",
        cast(t ->> 'qualification_type_lid' AS integer) AS "qualification_type_lid",
		 t ->> 'topic_of_study' AS "topic_of_study",
		 t ->> 'university' AS "university",
		 t ->> 'institute'  AS "institute",
		 cast(t ->> 'percentile' AS numeric(6,3)) AS "percentile",
		 t ->> 'year_of_passing' AS "year_of_passing",
		 t ->> 'url_path' AS "url_path",
		 cast(t ->> 'status' as boolean) as "is_completed"
		 
		 FROM jsonb_array_elements(input_jsonb['qualificationDetails']) AS t;
		 
		 
with inserted_id AS( 	 
	insert into resume_qualification(resume_lid,qualification_type_lid,topic_of_study,university,institute,percentile,year_of_passing,url_path, is_completed)	 
	select 	resume_lid,qualification_type_lid,topic_of_study,university,institute,percentile,year_of_passing,url_path, is_completed from temp_qualification 
	RETURNING resume_qualification_lid
	)
	select  into output_json json_agg(json_build_object('resume_qualification_lid',resume_qualification_lid)) from inserted_id;
	
	output_result := '{"status":200, "message":"Successfull"}';
	output_result['data'] := output_json;
	
	RETURN  output_result;

	END;
	
$$;
 D   DROP FUNCTION public.insert_qualification_details(input_json text);
       public          postgres    false            
           1255    87032    insert_research(text)    FUNCTION     ?
  CREATE FUNCTION public.insert_research(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE 
      output_result JSONB;
      input_jsonb jsonb := input_json;
	  output_json JSONB;
 BEGIN
  
  drop table if exists temp_research;
  create table temp_research
	(  id serial,
	   resume_lid int,
	   achievement_type_lid int,
	   organization_name varchar(500) ,
	   title varchar(100) not null,
	   organization_type_lid int,
	   achievement_date date ,
	   description varchar(100),
	   url_path varchar(500),
	   duration varchar(100),
	   volume_year varchar(100), 
	   category varchar(100), 
	   research_url_path varchar(255), 
	   active boolean default(true) not null
	   );
	   
	 drop table if exists ids;
	 create temporary table ids(
	 id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	 resume_achievement_lid int 
	 );
	
	insert into temp_research( resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration,volume_year,category,research_url_path)
	select cast(t ->> 'resume_lid' AS integer) "resume_lid",
		   cast(t ->> 'achievement_type_lid' AS integer) AS "achievement_type_lid",
		        t ->> 'title' AS "title",
				t ->> 'description' AS "description",
		        t ->> 'organization_name' AS "organization_name",				
		   cast(t ->> 'organization_type_lid' AS integer) AS "organization_type_lid",
		    	t ->> 'url_path' AS "url_path",
		   cast(t ->> 'achievement_date' AS date) AS "achievement_date",				
				t ->> 'duration' AS "duration",
				t ->> 'volume_year' AS "volume_year",
				t ->> 'category' AS "category",
				t ->> 'research_url_path' AS "research_url_path"
	from jsonb_array_elements(input_jsonb['insert_research']) AS t;
	
	with last_ids AS(
	     insert into resume_achievement(resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration)
		 select resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration from temp_research
		 RETURNING resume_achievement_lid
		 )
		 insert into ids(resume_achievement_lid)
		 select resume_achievement_lid from last_ids;
		 
	with inserted_id AS(
		 insert into resume_research(resume_achievement_lid,volume_year,category,research_url_path)
		 select ids.resume_achievement_lid,r.volume_year,r.category,r.research_url_path
		 from temp_research r
		 inner join ids on ids.id = r.id
		 RETURNING resume_achievement_lid
	     )
		 select  into output_json json_agg(json_build_object('resume_achievement_lid',resume_achievement_lid)) from inserted_id;	 
		
	    output_result := '{"status":200, "message":"Successfull"}';
	    output_result['data'] := output_json;
	
	    RETURN  output_result;

		 
		
END;	
$$;
 7   DROP FUNCTION public.insert_research(input_json text);
       public          postgres    false                       1255    87033    insert_skill_details(text)    FUNCTION     #  CREATE FUNCTION public.insert_skill_details(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
	
DECLARE 
	output_result JSONB;
	input_jsonb JSONB := input_json;
	output_json JSONB;
BEGIN

   drop table if exists temp_skill_details;
   create TEMPORARY table temp_skill_details (
    id serial,
     resume_lid  int not null,
	 skill_lid int not null 
	);
	
	insert into temp_skill_details(resume_lid,skill_lid)
	select cast(t ->> 'resume_lid' AS integer) AS "resume_lid",
	       cast(t ->> 'skill_lid' AS integer) AS "skill_lid"
		   from jsonb_array_elements(input_jsonb['skill_details']) AS t;
		   
 with inserted_id AS(
		insert into resume_skill_selected(resume_lid,skill_lid)
	    select resume_lid,skill_lid  from temp_skill_details RETURNING resume_skill_selected_lid
		)
	select  into output_json json_agg(json_build_object('resume_skill_selected_lid',resume_skill_selected_lid)) from inserted_id;
	output_result := '{"status":200, "message":"Successfull"}';
	output_result['data'] := output_json;
	
	RETURN  output_result;

	END;
	
$$;
 <   DROP FUNCTION public.insert_skill_details(input_json text);
       public          postgres    false                       1255    87034    insert_user_details(text)    FUNCTION       CREATE FUNCTION public.insert_user_details(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result JSONB;
input_jsonb JSONB := input_json;
output_json JSONB;

BEGIN

drop table if exists temp_user_address;
CREATE TEMPORARY TABLE temp_user_address (
         user_lid INTEGER NOT NULL,
         address VARCHAR(1000) NOT NULL,
         address_type_lid INTEGER NOT NULL,
         city varchar(100),
         pin_code varchar(100),
         resume_lid int not null
);

INSERT INTO temp_user_address(user_lid, address, address_type_lid,city,pin_code,resume_lid)
SELECT 
      CAST(t ->> 'user_lid' AS INTEGER) AS "user_lid",  
           t ->> 'address' AS "address",
      CAST(t ->> 'address_type_lid' AS INTEGER) AS "address_type_lid",	    
		   t ->> 'city' AS "city",    
	       t ->> 'pin_code' AS "pin_code",		
	  CAST(t ->> 'resume_lid' AS int) AS "resume_lid"
FROM jsonb_array_elements(input_jsonb['insert_user_personal_details']['user_address']) AS t;

  
drop table if exists temp_user_info;
CREATE TEMPORARY TABLE temp_user_info(
               user_lid INTEGER NOT NULL,
               f_name varchar(100) not null,
               l_name varchar(100) not null,
               email varchar(100),
	           date_of_birth date,					
			   pancard_no varchar(15) not null,
	           aadhar_card_no varchar(15),					
               temp_email varchar(150),
               gender_lid INTEGER NOT NULL,
			   pancard_url_path varchar(150) not null,
               aadhar_card_url_path varchar(150),						   
			   profile_url_path varchar(250) not null,
               nationality varchar(100),
               resume_lid int not null
);

  
INSERT INTO temp_user_info(user_lid,f_name,l_name,email,date_of_birth,pancard_no,aadhar_card_no,temp_email,gender_lid,pancard_url_path,aadhar_card_url_path, profile_url_path,nationality,resume_lid)
SELECT  
      CAST(t ->> 'user_lid' AS INTEGER) AS "user_lid",
           t ->> 'f_name' AS "f_name",
           t ->> 'l_name' AS "l_name",
           t ->> 'email' AS "email",
      CAST(t ->> 'date_of_birth' AS DATE) AS "date_of_birth ",
	       t ->> 'pancard_no' AS "pancard_no",
		   t ->> 'aadhar_card_no' AS "aadhar_card_no",
		   t ->> 'temp_email' AS "temp_email",
      CAST(t ->> 'gender_lid' AS INTEGER) AS "gender_lid",
		   t ->> 'pancard_url_path' AS "pancard_url_path",
		   t ->> 'aadhar_card_url_path' AS "aadhar_card_url_path",
           t ->> 'profile_url_path' AS "profile_url_path",
           t ->> 'nationality' AS "nationality",
	 cast(t ->> 'resume_lid' AS int) AS "resume_lid"
FROM jsonb_array_elements(input_jsonb['insert_user_personal_details']['user_info']) AS t;
                   
drop table if exists temp_user_contact;
CREATE TEMPORARY table temp_user_contact(
              user_lid integer not null,
              contact_number varchar(10) not null,
			  temp_contact_number varchar(10),
			  resume_lid int not null
);

INSERT INTO temp_user_contact(user_lid,contact_number,temp_contact_number,resume_lid)
select  
	   CAST(t ->> 'user_lid' AS INTEGER) AS "user_lid",
            t ->> 'contact_number' AS "contact_number",
		    t ->> 'temp_contact_number' AS "temp_contact_number",
	   CAST(t ->> 'resume_lid' AS int ) AS "resume_lid"
FROM jsonb_array_elements(input_jsonb['insert_user_personal_details']['user_contact']) AS t;

 
with inserted_id AS( 
   INSERT INTO user_info (user_lid,f_name,l_name,email,date_of_birth,pancard_no,temp_email,gender_lid,pancard_url_path,aadhar_card_url_path, profile_url_path,nationality,resume_lid)
   select user_lid, f_name, l_name,email,date_of_birth,pancard_no,temp_email,gender_lid,pancard_url_path,aadhar_card_url_path, profile_url_path,nationality,resume_lid from temp_user_info
   RETURNING user_lid
   )
select  into output_json json_agg(json_build_object('user_lid',user_lid)) from inserted_id;	
		
with inserted_id AS(
  INSERT INTO user_address(user_lid, address, address_type_lid,city,pin_code,resume_lid)
  SELECT user_lid, address, address_type_lid,city,pin_code,resume_lid FROM temp_user_address
  RETURNING user_lid
  )
select  into output_json json_agg(json_build_object('user_lid',user_lid)) from inserted_id;

with inserted_id AS(
   INSERT INTO user_contact(user_lid,contact_number,temp_contact_number,resume_lid)
   select user_lid ,contact_number,temp_contact_number,resume_lid from temp_user_contact
  RETURNING user_lid
  )
select  into output_json json_agg(json_build_object('user_lid',user_lid)) from inserted_id;

output_result := '{"status":200, "message":"Successfull"}';
output_result['data'] := output_json;

	RETURN  output_result;
END;
$$;
 ;   DROP FUNCTION public.insert_user_details(input_json text);
       public          postgres    false                       1255    87035    insert_work_experience(text)    FUNCTION     ?  CREATE FUNCTION public.insert_work_experience(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE 
       output_result JSONB;
       input_jsonb jsonb := input_json;
	   output_json JSONB;
	  
 BEGIN
 
    drop table if exists temp_work;
    create  temporary table temp_work(
    id serial ,
	resume_lid int not null ,
	experience_type_lid int not null,
	employer_name varchar(100) not null,
	designation varchar(100) not null,
	designation_lid int,
	description varchar(500) not null,
	start_date date ,
	end_date date ,
	responsibilities varchar(100) not null,
    is_current boolean,
    duration varchar(100),
    padagogy varchar(100)
	);
	
	
INSERT INTO temp_work(resume_lid,experience_type_lid,employer_name,designation,designation_lid,description,start_date,end_date,responsibilities,is_current,duration,padagogy)
SELECT 
     CAST(t ->> 'resume_lid' AS integer) AS "resume_lid",
     CAST(t ->> 'experience_type_lid' AS integer) AS "experience_type_lid",
	      t ->> 'employer_name' AS "employer_name",
		  t ->> 'designation' AS "designation",
	 CAST(t ->> 'designation_lid' AS integer) AS "designation_lid",
	      t ->> 'description' AS "description",
	 CAST(t ->> 'start_date' AS date) "start_date",
	 CAST(t ->> 'end_date' AS date) AS "end_date",
	      t ->> 'responsibilities' AS "responsibilities",
     CAST(t ->> 'is_current' AS boolean) AS "is_current",
          t ->> 'duration' AS  "duration",
		  t ->> 'padagogy' AS "padagogy"
FROM jsonb_array_elements(input_jsonb['work_Experience']) AS t;
	   
 with inserted_id AS(   
   INSERT INTO resume_experience(resume_lid,experience_type_lid,employer_name,designation,designation_lid,description,start_date,end_date,responsibilities,is_current,duration,padagogy)
   SELECT resume_lid,experience_type_lid,employer_name,designation,designation_lid,description,start_date,end_date,responsibilities,is_current,duration,padagogy from temp_work
	 RETURNING resume_experience_lid
	 )
SELECT INTO output_json json_agg(json_build_object('resume_experience_lid',resume_experience_lid)) FROM inserted_id;
    output_result := '{"status":200, "message":"Successfull"}';
	output_result['data'] := output_json;
	
	RETURN  output_result;

END;
$$;
 >   DROP FUNCTION public.insert_work_experience(input_json text);
       public          postgres    false                       1255    87036    max_points(integer)    FUNCTION     1  CREATE FUNCTION public.max_points(input_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
output_result   decimal (5,2);
input_qualification  decimal (5,2);
input_skill  decimal (5,2);
input_achievement  decimal (5,2);
input_designation  decimal (5,2);
input_experience  decimal (5,2);

BEGIN

--application_resume_qualification
input_qualification :=
(select sum(qb.points) from 
(
select rq.qualification_type_lid,rq.application_lid,count(*),
case when count(*) < (rp.max_limit)
then (rp.max_points) / (rp.max_limit) * count(*)
else (rp.max_points) end AS points
from application_resume_qualification rq 
inner join qualification_type qt on qt.id = rq.qualification_type_lid
inner join resume_profile_category rp on rp.foreign_lid = qt.id where rq.application_lid = input_id and rp.parent_lid =1 and rq.is_completed = true
group by rq.qualification_type_lid,rq.application_lid,rp.max_points,rp.max_limit
) qb );

---application_resume_skill_selected
input_skill :=
(select sum(qb.points) from 
(
select s.skill_type_lid,rss.application_lid,count(*),
case when count(*) < (rp.max_limit)
then (rp.max_points) / (rp.max_limit) * count(*)
else (rp.max_points) end AS points
from application_resume_skill_selected rss
inner join skill s on s.id = rss.skill_lid
inner join skill_type st on st.id = s.skill_type_lid 
inner join resume_profile_category rp on rp.foreign_lid = st.id and rss.application_lid = input_id and rp.parent_lid = 2
group by s.skill_type_lid,rss.application_lid,rp.max_points,rp.max_limit
) qb );

--application_resume_achivement
input_achievement :=
(select sum(qb.points) from 
(
select ar.achievement_type_lid,ar.application_lid,count(*),
case when count(*) < (rp.max_limit)
then (rp.max_points) / (rp.max_limit) * count(*)
else (rp.max_points) end AS points
from application_resume_achievement ar
inner join achievement_type ac on  ac.id = ar.achievement_type_lid
inner join resume_profile_category  rp on rp.foreign_lid = ac.id  where ar.application_lid = input_id and rp.parent_lid = 3
group by ar.achievement_type_lid,ar.application_lid,rp.max_points,rp.max_limit
) qb );

--designation
-- input_designation :=
-- (select d.points from designation d  
-- INNER JOIN application_resume_experience re ON d.id = re.designation_lid
-- where re.application_lid = input_id and re.is_current = true order by d.points desc limit 1);

--application_resume_experience
input_experience :=
(select COALESCE(range_point , 0.00) AS range_point from profile_category_settings where profile_category_id = 11 and
(select sum(DATE_PART('year',AGE(end_date,start_date))) AS total_exp from application_resume_experience where application_lid = input_id)
between range_start and range_end limit 1) + 
(select d.points from designation d  
INNER JOIN application_resume_experience re ON d.id = re.designation_lid
where re.application_lid = input_id and re.is_current = true order by d.points desc limit 1);

output_result := COALESCE(input_qualification , 00.00) + COALESCE(input_skill , 00.00) + COALESCE(input_achievement , 00.00) + COALESCE(input_experience , 00.00) ;

 return output_result; 
END
$$;
 3   DROP FUNCTION public.max_points(input_id integer);
       public          postgres    false                       1255    87037    max_points_1(integer)    FUNCTION     s  CREATE FUNCTION public.max_points_1(input_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$

declare
output_result JSONB :='{}';

BEGIN

drop table if exists profile_category;
create TEMPORARY table profile_category(
	category_id int,
	category_name varchar(100),
	points decimal(5,2),
	primary key(category_id)
	);
	
drop table if exists profile_category_output;	
create TEMPORARY table profile_category_output(
	category_id int,
	category_name varchar(100),
	points decimal(5,2),
	primary key(category_id)
	);
		
	
insert into profile_category(category_id,category_name)
select rp.id,rp.name from resume_profile_category rp where id in(1,2,3,4);

insert into profile_category_output(category_id,category_name)
select rp.id,rp.name from resume_profile_category rp where id in(1,2,3,4);

-- select * from profile_category
-- select * from profile_category_output

insert into profile_category_output(category_id,category_name)values(100,'total');

update profile_category set points =(select sum(qb.points) from 
(
select rq.qualification_type_lid,rq.application_lid,count(*),
case when count(*) < (rp.max_limit)
then (rp.max_points) / (rp.max_limit) * count(*)
else (rp.max_points) end AS points
from application_resume_qualification rq 
inner join qualification_type qt on qt.id = rq.qualification_type_lid
inner join resume_profile_category rp on rp.foreign_lid = qt.id and rq.application_lid = input_id and rp.parent_lid =1 and rq.is_completed = true
group by rq.qualification_type_lid,rq.application_lid,rp.max_points,rp.max_limit
) qb ) where category_id = 1;

update profile_category_output set points =(select sum(qb.points) from 
(
select rq.qualification_type_lid,rq.application_lid,count(*),
case when count(*) < (rp.max_limit)
then (rp.max_points) / (rp.max_limit) * count(*)
else (rp.max_points) end AS points
from application_resume_qualification rq 
inner join qualification_type qt on qt.id = rq.qualification_type_lid
inner join resume_profile_category rp on rp.foreign_lid = qt.id and rq.application_lid = input_id and rp.parent_lid =1 and rq.is_completed = true
group by rq.qualification_type_lid,rq.application_lid,rp.max_points,rp.max_limit
) qb ) where category_id = 1;

update profile_category set points =(select sum(qb.points) from 
(
select s.skill_type_lid,rss.application_lid,count(*),
case when count(*) < (rp.max_limit)
then (rp.max_points) / (rp.max_limit) * count(*)
else (rp.max_points) end AS points
from application_resume_skill_selected rss
inner join skill s on s.id = rss.skill_lid
inner join skill_type st on st.id = s.skill_type_lid 
inner join resume_profile_category rp on rp.foreign_lid = st.id and rss.application_lid = input_id and rp.parent_lid = 2
group by s.skill_type_lid,rss.application_lid,rp.max_points,rp.max_limit
) qb )
where category_id = 2;
update profile_category_output set points =(select sum(qb.points) from 
(
select s.skill_type_lid,rss.application_lid,count(*),
case when count(*) < (rp.max_limit)
then (rp.max_points) / (rp.max_limit) * count(*)
else (rp.max_points) end AS points
from application_resume_skill_selected rss
inner join skill s on s.id = rss.skill_lid
inner join skill_type st on st.id = s.skill_type_lid 
inner join resume_profile_category rp on rp.foreign_lid = st.id and rss.application_lid = input_id and rp.parent_lid = 2
group by s.skill_type_lid,rss.application_lid,rp.max_points,rp.max_limit
) qb )
where category_id = 2;

update profile_category set points = (select sum(qb.points) from 
(
select ar.achievement_type_lid,ar.application_lid,count(*),
case when count(*) < (rp.max_limit)
then (rp.max_points) / (rp.max_limit) * count(*)
else (rp.max_points) end AS points
from application_resume_achievement ar
inner join achievement_type ac on  ac.id = ar.achievement_type_lid
inner join resume_profile_category  rp on rp.foreign_lid = ac.id  and ar.application_lid = input_id and rp.parent_lid = 3
group by ar.achievement_type_lid,ar.application_lid,rp.max_points,rp.max_limit
) qb ) where category_id =3;

update profile_category_output set points = (select sum(qb.points) from 
(
select ar.achievement_type_lid,ar.application_lid,count(*),
case when count(*) < (rp.max_limit)
then (rp.max_points) / (rp.max_limit) * count(*)
else (rp.max_points) end AS points
from application_resume_achievement ar
inner join achievement_type ac on  ac.id = ar.achievement_type_lid
inner join resume_profile_category  rp on rp.foreign_lid = ac.id  and ar.application_lid = input_id and rp.parent_lid = 3
group by ar.achievement_type_lid,ar.application_lid,rp.max_points,rp.max_limit
) qb ) where category_id =3;

update profile_category set points = (select d.points from designation d  
INNER JOIN application_resume_experience re ON d.id = re.designation_lid
where re.application_lid = input_id and re.is_current = true order by d.points desc limit 1) + (select COALESCE(range_point , 0.00) AS range_point from profile_category_settings where profile_category_id = 11 and
(select sum(DATE_PART('year',AGE(end_date,start_date))) AS total_exp from application_resume_experience where application_lid = input_id)
between range_start and range_end limit 1) where category_id = 4;

update profile_category_output set points = (select d.points from designation d  
INNER JOIN application_resume_experience re ON d.id = re.designation_lid
where re.application_lid = input_id and re.is_current = true order by d.points desc limit 1) + (select COALESCE(range_point , 0.00) AS range_point from profile_category_settings where profile_category_id = 11 and
(select sum(DATE_PART('year',AGE(end_date,start_date))) AS total_exp from application_resume_experience where application_lid = input_id)
between range_start and range_end limit 1) where category_id = 4;

update profile_category_output set points = (select sum(points) from profile_category) where category_id =100;

output_result :=(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT pc.category_name,pc.points from profile_category_output pc)t);

return output_result ; 
END
$$;
 5   DROP FUNCTION public.max_points_1(input_id integer);
       public          postgres    false                       1255    87038    max_points_2(integer)    FUNCTION     ?  CREATE FUNCTION public.max_points_2(input_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result jsonb:= '{}';
input_result jsonb;

-- input_qualification  decimal (5,2);
-- input_skill  decimal (5,2);
-- input_achievement  decimal (5,2);
-- input_designation  decimal (5,2);
-- input_experience  decimal (5,2);

BEGIN

--application_resume_qualification
output_result['qualification'] := 
COALESCE((SELECT SUM(qb.points ::decimal(5,2)) FROM 
(
SELECT rq.qualification_type_lid,rq.application_lid,COUNT(*),
CASE WHEN COUNT(*) < (rp.max_limit)
THEN (rp.max_points) / (rp.max_limit) * count(*)
ELSE (rp.max_points) END AS points
FROM application_resume_qualification rq 
INNER JOIN qualification_type qt ON qt.id = rq.qualification_type_lid
INNER JOIN resume_profile_category rp ON rp.foreign_lid = qt.id WHERE rq.application_lid = input_id AND rp.parent_lid =1 AND rq.is_completed = true
GROUP BY rq.qualification_type_lid,rq.application_lid,rp.max_points,rp.max_limit
) qb ),0);

---application_resume_skill_selected
output_result['skill'] :=
COALESCE((SELECT SUM(qb.points ::decimal(5,2)) FROM 
(
SELECT s.skill_type_lid,rss.application_lid,COUNT(*),
CASE WHEN COUNT(*) < (rp.max_limit)
THEN (rp.max_points) / (rp.max_limit) * count(*)
ELSE (rp.max_points) END AS points
FROM application_resume_skill_selected rss
INNER JOIN skill s ON s.id = rss.skill_lid
INNER JOIN skill_type st ON st.id = s.skill_type_lid 
INNER JOIN resume_profile_category rp ON rp.foreign_lid = st.id AND rss.application_lid = input_id AND rp.parent_lid = 2
GROUP BY s.skill_type_lid,rss.application_lid,rp.max_points,rp.max_limit
) qb ),0);

--application_resume_achivement
output_result['achievement'] :=
COALESCE((SELECT SUM(qb.points ::decimal(5,2)) FROM 
(
SELECT ar.achievement_type_lid,ar.application_lid,COUNT(*),
CASE WHEN COUNT(*) < (rp.max_limit)
THEN (rp.max_points) / (rp.max_limit) * COUNT(*)
ELSE (rp.max_points) END AS points
from application_resume_achievement ar
INNER JOIN achievement_type ac ON  ac.id = ar.achievement_type_lid
INNER JOIN resume_profile_category  rp ON rp.foreign_lid = ac.id  WHERE ar.application_lid = input_id AND rp.parent_lid = 3
GROUP BY ar.achievement_type_lid,ar.application_lid,rp.max_points,rp.max_limit
) qb ),0);

--designation
-- input_designation :=
-- (select d.points from designation d  
-- INNER JOIN application_resume_experience re ON d.id = re.designation_lid
-- where re.application_lid = input_id and re.is_current = true order by d.points desc limit 1);

--application_resume_experience
output_result['experience'] :=
COALESCE ((SELECT COALESCE(range_point , 0.00) AS range_point FROM profile_category_settings WHERE profile_category_id = 11 AND
(SELECT SUM(DATE_PART('year',AGE(end_date,start_date))) AS total_exp FROM application_resume_experience WHERE application_lid = input_id)
BETWEEN range_start AND range_end LIMIT 1),0) + 
COALESCE ((SELECT (d.points ::decimal(5,2))FROM designation d  
INNER JOIN application_resume_experience re ON d.id = re.designation_lid
WHERE re.application_lid = input_id AND re.is_current = true ORDER BY d.points DESC LIMIT 1),0);

input_result := COALESCE (output_result['qualification'] ::decimal(5,2),00.00) + COALESCE (output_result['skill'] ::decimal(5,2),00.00) + COALESCE (output_result['achievement'] ::decimal(5,2),00.00) +  COALESCE (output_result['experience'] ::decimal(5,2),00.00);
 output_result['total_points'] := input_result;
	
RETURN output_result; 
END
$$;
 5   DROP FUNCTION public.max_points_2(input_id integer);
       public          postgres    false            *           1255    128306    offer_letter_insert()    FUNCTION     q  CREATE FUNCTION public.offer_letter_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
IF (NEW.status_lid = 1 AND new.level = 7) OR (NEW.status_lid = 4 AND new.level = 3) THEN
    INSERT INTO offer_letter_details(proforma_id, created_by, approved_by) VALUES (NEW.proforma_id, NEW.created_by, NEW.modified_by);
    RETURN NEW;
END IF;
RETURN NULL;
END;
$$;
 ,   DROP FUNCTION public.offer_letter_insert();
       public          postgres    false                       1255    87039    proforma_filter_1(text)    FUNCTION     ?Z  CREATE FUNCTION public.proforma_filter_1(input_data text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
-- DO
-- $$
declare
input_jsonb JSONB := input_data;
-- '{ 
--   "get_filter": [
--     {
--       "filter_id": "1",
--       "level": "1",
--       "status_lid": 1,
--       "filter_date": "01-01-2022",
--       "organization_lid": "50008171",
--       "program_id": "50008768",
--       "acad_session": null,
--       "module_id": null
--     }
--   ]
-- }
-- ';
output_result JSONB :='{}';
--SELECT * FROM temp_data
BEGIN
DROP TABLE IF EXISTS temp_data;
CREATE TEMPORARY TABLE temp_data (
	id SERIAL,	
	filter_id INT,
	level INT,
	filter_date date,
	organization_lid VARCHAR(100),
	program_id VARCHAR(100),
	acad_session VARCHAR(255),
	module_id INT,
	status_lid INT
	
);

INSERT INTO temp_data(filter_id,level,filter_date,organization_lid,program_id,acad_session,module_id,status_lid)
SELECT CAST(t ->> 'filter_id' AS INT),
       CAST(t ->> 'level' AS INT),
	   CAST(IIF(t ->> 'filter_date' = '', NULL, t ->> 'filter_date') AS DATE),
	        t ->> 'organization_lid',
		    t ->> 'program_id',
	        t ->> 'acad_session',
	   CAST(t ->> 'module_id' AS int),
	   CAST(t ->> 'status_lid' AS int)	
FROM jsonb_array_elements(input_jsonb['get_filter']) AS t;
-- END $$
-- 1 = School Filter , 2 = Program Filter , 3 = Semester Filter, 4= Date Filter, 5 = Status Filter 
CASE (SELECT filter_id from temp_data)

WHEN 1 THEN 

IF(SELECT level FROM temp_data) IN(1,2) THEN

	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid)
	FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
	TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id,pd.status_lid, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
	pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid AND pd.status_lid IN (1,3)
	AND pd.level = (SELECT level FROM temp_data) AND pd.active = TRUE AND ua.organization_lid In (SELECT organization_lid FROM temp_data)
	AND pd.program_id = (SELECT program_id FROM temp_data) ORDER BY pd.created_date) t1 
INNER JOIN 
	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

 ELSIF (SELECT level FROM temp_data) = 3 THEN
 
	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.level = (SELECT level FROM temp_data) AND pd.status_lid = 1 AND pd.active = TRUE	ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

ELSE 

    output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid AND pd.status_lid IN (1,3)
	AND pd.level = (SELECT level FROM temp_data)  AND pd.active = TRUE
	AND pd.program_id = (SELECT program_id FROM temp_data)  ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;
	
END IF;

WHEN 2 THEN 

IF(SELECT level FROM temp_data) IN(1,2) THEN

	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid)
	FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
	TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id,pd.status_lid, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
	pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid AND pd.status_lid IN (1,3)
	AND pd.level = (SELECT level FROM temp_data) AND pd.active = TRUE AND ua.organization_lid In (SELECT organization_lid FROM temp_data)
	AND pd.program_id = (SELECT program_id FROM temp_data) AND pd.acad_session = (SELECT acad_session FROM temp_data) ORDER BY pd.created_date) t1 
INNER JOIN 
	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

 ELSIF (SELECT level FROM temp_data) = 3 THEN
 
	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.level = (SELECT level FROM temp_data) AND pd.status_lid = 1
	AND pd.program_id = (SELECT program_id FROM temp_data) AND pd.acad_session = (SELECT acad_session FROM temp_data) ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

ELSE 

    output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid AND pd.status_lid IN (1,3)
	AND pd.level = (SELECT level FROM temp_data)  AND pd.active = TRUE 
	AND pd.program_id = (SELECT program_id FROM temp_data) AND pd.acad_session = (SELECT acad_session FROM temp_data) ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;
	
END IF;

WHEN 3 THEN 
 
IF(SELECT level FROM temp_data) IN(1,2) THEN

	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid)
	FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
	TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id,pd.status_lid, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
	pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid AND pd.status_lid IN (1,3)
	AND pd.level = (SELECT level FROM temp_data) AND pd.active = TRUE AND ua.organization_lid In (SELECT organization_lid FROM temp_data)
	AND pd.created_date::DATE = (SELECT filter_date FROM temp_data) ORDER BY pd.created_date) t1 
INNER JOIN 
	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

 ELSIF (SELECT level FROM temp_data) = 3 THEN
 
	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.level = (SELECT level FROM temp_data) AND pd.status_lid = 1
	AND pd.created_date::DATE = (SELECT filter_date FROM temp_data) ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

ELSE 

    output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid AND pd.status_lid IN (1,3)
	AND pd.level = (SELECT level FROM temp_data)  AND pd.active = TRUE 
	AND pd.created_date::DATE = (SELECT filter_date FROM temp_data) ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;
	
END IF;

WHEN 4 THEN

IF(SELECT level FROM temp_data) IN(1,2) THEN

	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid)
	FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
	TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id,pd.status_lid, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
	pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid  
	AND pd.level = (SELECT level FROM temp_data) AND pd.active = TRUE AND ua.organization_lid In (SELECT organization_lid FROM temp_data)
	AND pd.status_lid = (SELECT status_lid FROM temp_data) ORDER BY pd.created_date) t1 
INNER JOIN 
	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

 ELSIF (SELECT level FROM temp_data) = 3 THEN
 
	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.level = (SELECT level FROM temp_data) AND pd.status_lid = 1
	AND pd.status_lid = (SELECT status_lid FROM temp_data) ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

ELSE 

    output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	AND pd.level = (SELECT level FROM temp_data)  AND pd.active = TRUE 
	AND pd.status_lid = (SELECT status_lid FROM temp_data) ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;
	
END IF;

END CASE;
	RETURN output_result;
END 
$_$;
 9   DROP FUNCTION public.proforma_filter_1(input_data text);
       public          postgres    false            ?           1255    89425    proforma_filter_report(text)    FUNCTION     b  CREATE FUNCTION public.proforma_filter_report(input_data text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
-- DO
-- $$
declare
input_jsonb JSONB := input_data;
-- '{ 
--   "get_filter": [
--     {
--       "filter_id": "1",
--       "level": "1",
--       "status_lid": 1,
--       "filter_date": "01-01-2022",
--       "organization_lid": "50008171",
--       "program_id": "50008768",
--       "acad_session": null,
--       "module_id": null
--     }
--   ]
-- }
-- ';
output_result JSONB :='{}';
--SELECT * FROM temp_data
BEGIN
DROP TABLE IF EXISTS temp_data;
CREATE TEMPORARY TABLE temp_data (
	id SERIAL,	
	filter_id INT,
	level INT,
	filter_date date,
	organization_lid VARCHAR(100),
	program_id VARCHAR(100),
	acad_session VARCHAR(255),
	module_id INT,
	status_lid INT
	
);

INSERT INTO temp_data(filter_id,level,filter_date,organization_lid,program_id,acad_session,module_id,status_lid)
SELECT CAST(t ->> 'filter_id' AS INT),
       CAST(t ->> 'level' AS INT),
	   CAST(IIF(t ->> 'filter_date' = '', NULL, t ->> 'filter_date') AS DATE),
	        t ->> 'organization_lid',
		    t ->> 'program_id',
	        t ->> 'acad_session',
	   CAST(t ->> 'module_id' AS int),
	   CAST(t ->> 'status_lid' AS int)	
FROM jsonb_array_elements(input_jsonb['get_filter']) AS t;
-- END $$
CASE (SELECT filter_id from temp_data)

WHEN 3 THEN 

IF(SELECT level FROM temp_data) IN(1,2) THEN

	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid)
	FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
	TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.status_lid,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
	pd.aol_obe, pd.level, pd.modified_by,pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > (SELECT level from temp_data) and status_lid IN(1,2,3,4) OR pd.level = (SELECT level FROM temp_data) AND status_lid = 2)  
	AND pd.active = TRUE AND ua.organization_lid In (SELECT organization_lid FROM temp_data)
	AND pd.created_date::DATE = (SELECT filter_date FROM temp_data)
	ORDER BY pd.created_date) t1 
INNER JOIN 
	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

 ELSIF (SELECT level FROM temp_data) = 3 THEN
 
	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.status_lid,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.modified_by, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > (SELECT level from temp_data) and status_lid IN(1,2,3,4) OR pd.level = (SELECT level FROM temp_data) AND status_lid IN (2,4)) AND pd.active = TRUE
	AND pd.created_date::DATE = (SELECT filter_date FROM temp_data) ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

ELSE 

    output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.status_lid,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.modified_by, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > (SELECT level from temp_data) and status_lid IN(1,2,3,4) OR pd.level = (SELECT level FROM temp_data) AND status_lid = 2)AND pd.active = TRUE 
 	AND pd.created_date::DATE = (SELECT filter_date FROM temp_data) 
	ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;
	
END IF;

WHEN 1 THEN 

IF(SELECT level FROM temp_data) IN(1,2) THEN

	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid)
	FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
	TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.status_lid,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
	pd.aol_obe, pd.level, pd.modified_by, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > (SELECT level from temp_data) and status_lid IN(1,2,3,4) OR pd.level = (SELECT level FROM temp_data) AND status_lid = 2) AND pd.active = TRUE AND ua.organization_lid In (SELECT organization_lid FROM temp_data)
	AND pd.program_id = (SELECT program_id FROM temp_data) ORDER BY pd.created_date) t1 
INNER JOIN 
	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

 ELSIF (SELECT level FROM temp_data) = 3 THEN
 
	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.status_lid,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.modified_by, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > (SELECT level from temp_data) and status_lid IN(1,2,3,4) OR pd.level = (SELECT level FROM temp_data) AND status_lid IN (2,4))
	AND pd.active = TRUE	ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

ELSE 

    output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.status_lid,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.modified_by, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > (SELECT level from temp_data) and status_lid IN(1,2,3,4) OR pd.level = (SELECT level FROM temp_data) AND status_lid = 2) AND pd.active = TRUE
	AND pd.program_id = (SELECT program_id FROM temp_data)  ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;
	
END IF;

WHEN 2 THEN 

IF(SELECT level FROM temp_data) IN(1,2) THEN

	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid)
	FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
	TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.status_lid,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
	pd.aol_obe, pd.level, pd.modified_by, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > (SELECT level from temp_data) and status_lid IN(1,2,3,4) OR pd.level = (SELECT level FROM temp_data) AND status_lid = 2) AND pd.active = TRUE AND ua.organization_lid In (SELECT organization_lid FROM temp_data)
	AND pd.program_id = (SELECT program_id FROM temp_data) AND pd.acad_session = (SELECT acad_session FROM temp_data)
    ORDER BY pd.created_date) t1 
INNER JOIN 
	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

 ELSIF (SELECT level FROM temp_data) = 3 THEN
 
	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.status_lid,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.modified_by, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > (SELECT level from temp_data) and status_lid IN(1,2,3,4) OR pd.level = (SELECT level FROM temp_data) AND status_lid IN (2,4))
	AND pd.program_id = (SELECT program_id FROM temp_data) AND pd.acad_session = (SELECT acad_session FROM temp_data)
    ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

ELSE 

    output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.status_lid,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.modified_by, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > (SELECT level from temp_data) and status_lid IN(1,2,3,4) OR pd.level = (SELECT level FROM temp_data) AND status_lid = 2) AND pd.active = TRUE 
	AND pd.program_id = (SELECT program_id FROM temp_data) AND pd.acad_session = (SELECT acad_session FROM temp_data)
    ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;
	
END IF;

WHEN 4 THEN 

IF(SELECT level FROM temp_data) IN(1,2) THEN

	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid)
	FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
	TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.status_lid,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
	pd.aol_obe, pd.level, pd.modified_by, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid  
	WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > (SELECT level from temp_data) and status_lid IN(1,2,3,4) OR pd.level = (SELECT level FROM temp_data) AND status_lid = 2)
	AND pd.active = TRUE AND ua.organization_lid In (SELECT organization_lid FROM temp_data)
	AND pd.status_lid = (SELECT status_lid FROM temp_data) ORDER BY pd.created_date) t1 
INNER JOIN 
	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

 ELSIF (SELECT level FROM temp_data) = 3 THEN
 
	output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.status_lid,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.modified_by, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > (SELECT level from temp_data) and status_lid IN(1,2,3,4) OR pd.level = (SELECT level FROM temp_data) AND status_lid IN (2,4))
	AND pd.status_lid = (SELECT status_lid FROM temp_data) ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;

ELSE 

    output_result ['proforma_details'] := (SELECT JSONB_AGG(TO_JSONB(t3.*)) FROM (SELECT t1.*, t2.industrial_exp, t2.teaching_exp, t2.total_exp,max_points_2(t2.application_lid) FROM (SELECT ui.pancard_no, CONCAT(ui.f_name, ' ', ui.l_name) AS full_name, pd.application_lid, pd.module, pd.teaching_hours, pd.program_id, pd.acad_session,
    TO_CHAR(pd.created_date,'DD-MM-YYYY') AS created_date,pd.status_lid,pd.proforma_id, pd.rate_per_hours, pd.total_no_of_hrs_alloted, pd.no_of_division, pd.student_count_per_division,pd.program_name,pd.module_id,
    pd.aol_obe, pd.level, pd.modified_by, pd.commencement_date_of_program, ua.appln_id, ua.organization_lid, ap.name AS status 
	FROM proforma_details pd 
	INNER JOIN user_application ua ON pd.application_lid = ua.appln_id
	INNER JOIN application_status ap on ap.id = pd.status_lid 
	INNER JOIN application_user_info ui on pd.application_lid = ui.application_lid 
	WHERE pd.proforma_id IN(SELECT proforma_id FROM proforma_details WHERE level > (SELECT level from temp_data) and status_lid IN(1,2,3,4) OR pd.level = (SELECT level FROM temp_data) AND status_lid = 2)
	AND pd.status_lid = (SELECT status_lid FROM temp_data) ORDER BY pd.created_date) t1 
	INNER JOIN 

	(SELECT application_lid, COALESCE(industrial_exp, '0 days'::INTERVAL) AS industrial_exp, COALESCE(teaching_exp,  '0 days'::INTERVAL) AS teaching_exp, COALESCE(industrial_exp, '0 days'::INTERVAL) + COALESCE(teaching_exp, '0 days'::INTERVAL) AS total_exp 
	FROM crosstab('SELECT application_lid::INT, et.name, SUM(AGE(end_date, start_date)) AS total_exp FROM application_resume_experience ar
	INNER JOIN experience_type et ON et.id = ar.experience_type_lid
	GROUP BY experience_type_lid, application_lid, et.name ORDER BY 1,2') 
	AS final_result(application_lid INT, industrial_exp INTERVAL, teaching_exp INTERVAL)) t2
	ON t2.application_lid = t1.application_lid ) t3 ) ;
	
END IF;

END CASE;
	RETURN output_result;
END 
$_$;
 >   DROP FUNCTION public.proforma_filter_report(input_data text);
       public          postgres    false                       1255    87041    resume_search(text)    FUNCTION     ?  CREATE FUNCTION public.resume_search(input_text text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
output_result JSONB :='{}';
BEGIN
output_result ['resume_details'] := (SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT u.user_id,u.id AS user_lid,r.id,r.name,r.description 
																  FROM  public.user u
																  INNER JOIN resume r 
																  ON u.id = r.user_lid
																  WHERE u.id = CAST (input_text AS INT )) t);

RETURN output_result;
END
$$;
 5   DROP FUNCTION public.resume_search(input_text text);
       public          postgres    false                       1255    87042    update_achievement(text)    FUNCTION     u	  CREATE FUNCTION public.update_achievement(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE 
      input_jsonb jsonb := input_json;
 BEGIN
  
  DROP TABLE IF EXISTS temp_achievement;
  CREATE TABLE temp_achievement
	(  id serial,
	   resume_achievement_lid int not NULL,
	   resume_lid int,
	   achievement_type_lid int,
	   organization_name varchar(500) ,
	   title varchar(100) not null,
	   organization_type_lid int,
	   achievement_date date ,
	   description varchar(100),
	   url_path varchar(500),
	   duration varchar(100)
	   );
	
	INSERT INTO temp_achievement(resume_achievement_lid,resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration)
	SELECT CAST(t ->> 'resume_achievement_lid' AS integer) "resume_achievement_lid",
		   CAST(t ->> 'resume_lid' AS integer) "resume_lid",
		   CAST(t ->> 'achievement_type_lid' AS integer) AS "achievement_type_lid",
		        t ->> 'title' AS "title",
				t ->> 'description' AS "description",
		        t ->> 'organization_name' AS "organization_name",				
		   CAST(t ->> 'organization_type_lid' AS integer) AS "organization_type_lid",
		    	t ->> 'url_path' AS "url_path",
		   CAST(t ->> 'achievement_date' AS date) AS "achievement_date",				
				t ->> 'duration' AS "duration"
			
	FROM jsonb_array_elements(input_jsonb['insert_award']) AS t;
	
   IF(SELECT url_path FROM temp_achievement ) ISNULL THEN
	     UPDATE resume_achievement ra SET
		 resume_lid = i.resume_lid,
		 achievement_type_lid = i.achievement_type_lid,
		 title = i.title,
		 description = i.description,
		 organization_name = i.organization_name,
		 organization_type_lid = i.organization_type_lid,
		 achievement_date = i.achievement_date,
		 duration = i.duration
		 FROM temp_achievement i
		 WHERE i.resume_achievement_lid = ra.resume_achievement_lid;
		 
	ELSE
	     
		 UPDATE resume_achievement ra SET
		 resume_lid = i.resume_lid,
		 achievement_type_lid = i.achievement_type_lid,
		 title = i.title,
		 description = i.description,
		 organization_name = i.organization_name,
		 organization_type_lid = i.organization_type_lid,
		 url_path = i.url_path,
		 achievement_date = i.achievement_date,
		 duration = i.duration
		 FROM temp_achievement i
		 WHERE i.resume_achievement_lid = ra.resume_achievement_lid; 
		 
END IF;
    RETURN '{"status": 200, "message": "Successfull."}';

	END;
	
$$;
 :   DROP FUNCTION public.update_achievement(input_json text);
       public          postgres    false                       1255    87043    update_all_data()    FUNCTION     n  CREATE FUNCTION public.update_all_data() RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
declare
output_result JSONB :='{}';
BEGIN
output_result ['personal_details'] := (SELECT to_jsonb(t.*) FROM (SELECT u.id, u.user_id, ua.address,ua.address_type_lid,ui.email,ui.f_name,ui.l_name,
ui.date_of_birth,ui.pancard_no,ui.aadhar_card_no,ui.temp_email,ui.gender_lid,gd.name,ui.pancard_url_path,
ui.aadhar_card_url_path,ui.nationality,uc.contact_number,uc.temp_contact_number FROM public.user u
INNER JOIN user_info ui ON ui.user_lid = u.id
INNER JOIN user_gender gd ON gd.id = ui.gender_lid
INNER JOIN resume r ON r.user_lid = u.id
INNER JOIN user_address ua ON ua.user_lid = u.id
INNER JOIN user_contact uc ON uc.user_lid = u.id
WHERE
r.id = 1 AND
u.active = TRUE AND 
ui.active = TRUE AND 
ua.active = TRUE AND 
uc.active = TRUE) t);


output_result['resume_qualification'] :=(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT rq.resume_qualification_lid,rq.qualification_type_lid,rq.topic_of_study,
rq.university,rq.institute,rq.percentile,rq.year_of_passing,rq.url_path FROM resume_qualification rq
INNER JOIN resume r ON r.id = rq.resume_lid
INNER JOIN qualification_type qt ON qt.id = rq.qualification_type_lid
WHERE r.id = 1 AND rq.active = true)t);

output_result['resume_experience'] := (SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT re.resume_experience_lid,re.experience_type_lid,re.employer_name,
re.designation,re.designation_lid,re.description,re.start_date,re.end_date,re.responsibilities,re.is_current
FROM resume_experience  re
INNER JOIN resume r ON r.id = re.resume_lid
WHERE r.id = 1 AND re.active = true) t);

output_result['resume_skill_selected'] :=(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT rs.resume_skill_selected_lid,rs.skill_lid,sk.skill_name
FROM resume_skill_selected rs
INNER JOIN resume r ON r.id = rs.resume_lid
INNER JOIN skill sk ON sk.id = rs.skill_lid
WHERE r.id = 1 AND sk.active = TRUE AND rs.active = true)t);

output_result['resume_achievement'] :=
(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT ra.resume_achievement_lid,ra.achievement_type_lid,ra.title,ra.description,
ra.organization_name,ra.organization_type_lid,ra.url_path,ra.achievement_date,ra.duration
from resume_achievement ra 
INNER JOIN resume r ON r.id = ra.resume_lid
INNER JOIN achievement_type att ON att.id = ra.achievement_type_lid
WHERE r.id = 1 AND ra.achievement_type_lid = 2 AND ra.active = TRUE AND att.active = true)t);

output_result['resume_publication'] :=(SELECT jsonb_agg(to_jsonb(t.*)) FROM (SELECT rp.resume_achievement_lid,rp.publication_role,rp.no_of_authors,rp.publisher,ra.title,rp.year_of_publication,rp.publication_url_path
FROM resume_publication rp
INNER JOIN resume_achievement ra ON ra.resume_achievement_lid = rp.resume_achievement_lid
INNER JOIN resume r ON r.id = ra.resume_lid
WHERE r.id = 1 AND rp.active = TRUE AND ra.active = true)t);

output_result['resume_research'] :=(SELECT jsonb_agg(to_jsonb(t.*))FROM (SELECT rr.resume_achievement_lid,ra.title,rr.volume_year,ra.description,rr.category,rr.research_url_path
FROM resume_research rr
INNER JOIN resume_achievement ra ON ra.resume_achievement_lid = rr.resume_achievement_lid
INNER JOIN resume r ON r.id = ra.resume_lid
WHERE r.id = 1 AND rr.active = TRUE AND ra.active = TRUE)t);

output_result['bank_details'] :=
(SELECT to_jsonb(t.*) FROM (SELECT bd.user_lid,bd.bank_account_type_lid,bc.account_type,bd.bank_name,bd.branch_name,
bd.ifsc_code,bd.micr_code,bd.account_number,bd.url_path
FROM bank_details bd
INNER JOIN resume r ON r.user_lid = bd.user_lid
INNER JOIN bank_account_type bc ON bc.id = bd.bank_account_type_lid
WHERE r.id = 1 AND bd.active = TRUE AND bc.active = TRUE)t);
RETURN output_result;
END
$$;
 (   DROP FUNCTION public.update_all_data();
       public          postgres    false                       1255    87044    update_application(text)    FUNCTION       CREATE FUNCTION public.update_application(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE 
      input_jsonb jsonb := input_json;
						  

 BEGIN
  
 drop table if exists temp_application;
 create table temp_application(
  id serial,
  resume_lid int not null,
  organization_lid VARCHAR not null,
  application_lid int,
  active boolean default(true) not null
 );
 	   
	 drop table if exists ids;
	 create temporary table ids(
	 id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	 appln_id int 
	 );
	
 
 insert into temp_application(resume_lid,organization_lid,application_lid,active)
 select 
       cast(t ->> 'resume_lid' AS int) AS "resume_lid",
	   		t ->> 'organization_lid' "organization_lid",
	   cast(t ->> 'application_lid' AS int) AS "application_lid",
	   cast(t ->> 'active' AS boolean) AS "active"
 from jsonb_array_elements(input_jsonb['create_job_application']) AS t;
 
IF (SELECT application_lid FROM temp_application) NOTNULL THEN
	UPDATE user_application SET active = true where appln_id = (select application_lid from temp_application);

		insert into ids(appln_id)
		select application_lid from temp_application;
ELSE
	 with last_ids AS(
	 insert into user_application(resume_lid,organization_lid)
	 select resume_lid,organization_lid from temp_application
	 RETURNING appln_id
	 )
	 insert into ids(appln_id)
	select appln_id from last_ids;
END IF;
	
INSERT INTO application_user_info (user_lid,email,f_name,l_name,date_of_birth,pancard_no,aadhar_card_no,temp_email,gender_lid,pancard_url_path, profile_url_path,aadhar_card_url_path,nationality,resume_lid,application_lid)
select user_lid,email,f_name,l_name,date_of_birth,pancard_no,aadhar_card_no,temp_email,gender_lid,pancard_url_path, profile_url_path,aadhar_card_url_path,nationality,resume_lid,(select appln_id from ids) from user_info
where user_info.resume_lid = (select resume_lid from temp_application);
 
INSERT INTO application_user_address(user_lid, address, address_type_lid,city,pin_code,resume_lid,application_lid)
SELECT user_lid, address, address_type_lid,city,pin_code,resume_lid,(select appln_id from ids) FROM user_address
where user_address.resume_lid = (select resume_lid from temp_application);

INSERT INTO application_user_contact(user_lid,contact_number,temp_contact_number,resume_lid,application_lid)
select user_lid ,contact_number,temp_contact_number,resume_lid,(select appln_id from ids) from user_contact
where user_contact.resume_lid = (select resume_lid from temp_application);

insert into application_resume_qualification(resume_qualification_lid,resume_lid,qualification_type_lid,topic_of_study,university,institute,percentile,year_of_passing,url_path, is_completed,application_lid)	 
select resume_qualification_lid,resume_lid,qualification_type_lid,topic_of_study,university,institute,percentile,year_of_passing,url_path, is_completed,(select appln_id from ids) from resume_qualification
where resume_qualification.resume_lid = (select resume_lid from temp_application);

insert into application_resume_experience(resume_experience_lid,resume_lid,experience_type_lid,employer_name,designation,designation_lid,description,start_date,end_date,responsibilities,is_current,duration,padagogy,application_lid)
select resume_experience_lid,resume_lid,experience_type_lid,employer_name,designation,designation_lid,description,start_date,end_date,responsibilities,is_current,duration,padagogy,(select appln_id from ids) from resume_experience
where resume_experience.resume_lid = (select resume_lid from temp_application);

insert into application_resume_skill_selected(resume_skill_selected_lid,resume_lid,skill_lid,application_lid)
select resume_skill_selected_lid,resume_lid,skill_lid,(select appln_id from ids)  from resume_skill_selected
where resume_skill_selected.resume_lid = (select resume_lid from temp_application);

insert into application_resume_achievement(resume_achievement_lid,resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration,application_lid)
select resume_achievement_lid,resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration,(select appln_id from ids) from resume_achievement 
where resume_achievement.resume_lid = (select resume_lid from temp_application);
 
insert into application_resume_publication(resume_publication_lid,resume_achievement_lid,publication_role,no_of_authors,publisher,year_of_publication,publication_url_path,application_lid)
select rp.resume_publication_lid,rp.resume_achievement_lid,rp.publication_role,rp.no_of_authors,rp.publisher,rp.year_of_publication,rp.publication_url_path,(select appln_id from ids)
from resume_publication rp INNER JOIN resume_achievement ra ON rp.resume_achievement_lid = ra.resume_achievement_lid
AND ra.resume_lid = (select resume_lid from temp_application) AND ra.achievement_type_lid = 1;

insert into application_resume_research(resume_research_lid,resume_achievement_lid,volume_year,category,description,research_url_path,application_lid)
select rr.resume_research_lid,rr.resume_achievement_lid,rr.volume_year,rr.category,rr.description,rr.research_url_path,(select appln_id from ids)
from resume_research rr inner join resume_achievement ra on rr.resume_achievement_lid = ra.resume_achievement_lid
AND ra.resume_lid = (select resume_lid from temp_application) AND ra.achievement_type_lid = 3;

insert into application_bank_details(user_lid,bank_account_type_lid,resume_lid,bank_name,branch_name,ifsc_code,micr_code,account_number,url_path,application_lid)	 
select user_lid,bank_account_type_lid,resume_lid,bank_name,branch_name,ifsc_code,micr_code,account_number,url_path,(select appln_id from ids) from bank_details
where bank_details.resume_lid = (select resume_lid from temp_application);

 RETURN '{"status": 200, "message": "Successfull."}';

END
$$;
 :   DROP FUNCTION public.update_application(input_json text);
       public          postgres    false                       1255    87045    update_bank_details(text)    FUNCTION     ?  CREATE FUNCTION public.update_bank_details(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
	
DECLARE 
	input_jsonb JSONB := input_json;
BEGIN

   drop table if exists temp_bank_details;
   create TEMPORARY table temp_bank_details (
    id serial,
    user_lid int not null,
	bank_account_type_lid int not null ,
	bank_name varchar(100) not null,
	branch_name varchar(100) not null,
	ifsc_code varchar(100) not null,
	micr_code varchar(100) ,
	account_number varchar(100) not null,
	url_path varchar(100),
	active boolean DEFAULT(true) not null
 );
 
 insert into temp_bank_details(user_lid,bank_account_type_lid,bank_name,branch_name,ifsc_code,micr_code,account_number, url_path)
 select  cast(t ->> 'user_lid' AS integer) AS "user_lid",
        cast(t ->> 'bank_account_type_lid' AS integer) AS "bank_account_type_lid",
		 t ->> 'bank_name' AS "bank_name",
		 t ->> 'branch_name' AS "branch_name",
		 t ->> 'ifsc_code'  AS "ifsc_code",
		 t ->> 'micr_code'  AS "micr_code",
		 t ->> 'account_number' AS "account_number",
		 t ->> 'url_path' AS "url_path"
		 
		 FROM jsonb_array_elements(input_jsonb['insert_bank_data']) AS t;
	 
	 IF(select url_path from temp_bank_details) ISNULL then
	 update bank_details bd SET
	      bank_account_type_lid = i.bank_account_type_lid,
		  bank_name = i.bank_name,
		  branch_name = i.branch_name,
		  account_number = i.account_number,
	      ifsc_code = i.ifsc_code,
		  micr_code = i.micr_code
		  from temp_bank_details i where i.user_lid = bd.user_lid;
		
	ELSE	
		
		   update bank_details bd SET
	      bank_account_type_lid = i.bank_account_type_lid,
		  bank_name = i.bank_name,
		  branch_name = i.branch_name,
		  account_number = i.account_number,
	      ifsc_code = i.ifsc_code,
		  micr_code = i.micr_code,
		  url_path = i.url_path
		  from temp_bank_details i where i.user_lid = bd.user_lid;
END IF;

	 RETURN '{"status": 200, "message": "Successfull."}';

	END;
	
$$;
 ;   DROP FUNCTION public.update_bank_details(input_json text);
       public          postgres    false                       1255    87046    update_performa_details(text)    FUNCTION     L
  CREATE FUNCTION public.update_performa_details(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$

-- DO $$
declare

input_jsonb jsonb := input_json;

-- '{
--   "insert_proforma_status": [
--     {
--       "proforma_lid": 3,
--       "level": 3,
--       "status_lid": 2,
--       "comment": "Very Poor",
--       "file_path": "path"
--     }
--   ]
-- }'
  
BEGIN

drop table if exists temp_performa_details;
create TEMPORARY table temp_performa_details(
performa_id int,
application_lid int not null,
module varchar,
teaching_hours varchar(50),
program_id int not null,
acad_session varchar(100),
commencement_date_of_program date,
rate_per_hours int,
total_no_of_hrs_alloted int,
no_of_division int,
student_count_per_division int,
aol_obe varchar,
active boolean  not null default(true),
created_by varchar(100),
created_date timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
last_modified_by varchar(100),
last_modified_date timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

insert into temp_performa_details(performa_id,application_lid,module,teaching_hours,program_id,acad_session,commencement_date_of_program,rate_per_hours,total_no_of_hrs_alloted,no_of_division,student_count_per_division,aol_obe)
select cast(t ->> 'performa_id' AS int) "performa_id",
      cast(t ->> 'application_lid' AS int) "application_lid",
           t ->> 'module' AS  "module",
	        t ->> 'teaching_hours' AS "teaching_hours",
	   cast(t ->> 'program_id' AS int ) "program_id",
	        t ->> 'acad_session' AS "acad_session",
	   cast(t ->> 'commencement_date_of_program' AS date ) "commencement_date_of_program",
	   cast(t ->> 'rate_per_hours' AS int ) "rate_per_hours",
	   cast(t ->> 'total_no_of_hrs_alloted' AS int ) "total_no_of_hrs_alloted",
	   cast(t ->> 'no_of_division' AS int ) "no_of_division",
	   cast(t ->> 'student_count_per_division' AS int ) "student_count_per_division",
            t ->> 'aol_obe' AS "aol_obe"
from jsonb_array_elements(input_jsonb['insert_performa']) AS t;

update  performa_details pd set
   module = i.module,
   teaching_hours = i.teaching_hours,
   program_id = i.program_id,
   acad_session = i.acad_session,
   commencement_date_of_program = i.commencement_date_of_program,
   rate_per_hours = i.rate_per_hours,
   total_no_of_hrs_alloted = i.total_no_of_hrs_alloted,
   no_of_division = i.no_of_division,
   student_count_per_division = i.student_count_per_division,
   aol_obe = i.aol_obe
  from 	temp_performa_details i where i.performa_id = pd.performa_id;
   
--   END;
--   $$;
  
   RETURN '{"status": 200, "message": "Successfull."}';
	END;
$_$;
 ?   DROP FUNCTION public.update_performa_details(input_json text);
       public          postgres    false                       1255    87047    update_proforma_status(text)    FUNCTION     d  CREATE FUNCTION public.update_proforma_status(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$

-- DO $$
declare

input_jsonb jsonb := input_json;

-- '{
--   "insert_proforma_status": [
--     {
--       "proforma_lid": 3,
--       "level": 3,
--       "status_lid": 2,
--       "comment": "Very Poor",
--       "file_path": "path"
--     }
--   ]
-- }'
  

BEGIN

drop table if exists temp_proforma_status;
create TEMPORARY table temp_proforma_status(
id serial,
proforma_lid int NOT NULL,
approved_by varchar,
level int NOT NULL,
status_lid int not null,
comment varchar,
created_date timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
file_path varchar,
active boolean  not null default(true)
);

insert into temp_proforma_status(proforma_lid,approved_by,level,status_lid,comment,file_path)
select cast(t ->> 'proforma_lid' AS int) "proforma_lid",
            t ->> 'approved_by' AS  "approved_by",
	   cast(t ->> 'level' AS int ) "level",
	   cast(t ->> 'status_lid' AS int ) "status_lid",
	        t ->> 'comment' AS  "comment",
	        t ->> 'file_path' AS "file_path"
from jsonb_array_elements(input_jsonb['insert_proforma_status']) AS t;		
	
	CASE (SELECT status_lid from temp_proforma_status)
    WHEN 1 THEN 
			
	  if(select level from temp_proforma_status) = 1 THEN

			insert into proforma_status(proforma_lid,approved_by,level,status_lid,comment,file_path,tag_id)
			select tps.proforma_lid,tps.approved_by,tps.level,tps.status_lid,tps.comment,tps.file_path,pd.tag_id + 1 
			from temp_proforma_status tps INNER JOIN proforma_details pd on pd.proforma_id = tps.proforma_lid ;

			update proforma_details set tag_id = (select tag_id from proforma_details where proforma_id = (select proforma_lid from temp_proforma_status)) + 1,
			status_lid = (select status_lid from temp_proforma_status),
			modified_by = (SELECT approved_by FROM temp_proforma_status),
			level = (select level from temp_proforma_status) + 1  where proforma_id = (select proforma_lid from temp_proforma_status);

		ELSIF (select level from temp_proforma_status) = 6 THEN
		
            insert into proforma_status(proforma_lid,approved_by,level,status_lid,comment,file_path,tag_id)
			select tps.proforma_lid,tps.approved_by,tps.level,tps.status_lid,tps.comment,tps.file_path,pd.tag_id + 1 
			from temp_proforma_status tps INNER JOIN proforma_details pd on pd.proforma_id = tps.proforma_lid ;

			update proforma_details set tag_id = (select tag_id from proforma_details where proforma_id = (select proforma_lid from temp_proforma_status)) + 1,
			status_lid = (select status_lid from temp_proforma_status),
			modified_by = (SELECT approved_by FROM temp_proforma_status),
			level = (select level from temp_proforma_status) + 1  where proforma_id = (select proforma_lid from temp_proforma_status);
            
            INSERT INTO approved_faculty_status(proforma_lid,created_by)
            SELECT proforma_lid,approved_by FROM temp_proforma_status;
        ELSE 
        
		    insert into proforma_status(proforma_lid,approved_by,level,status_lid,comment,file_path,tag_id)
		    select tps.proforma_lid,tps.approved_by,tps.level,tps.status_lid,tps.comment,tps.file_path,pd.tag_id
		    from temp_proforma_status tps INNER JOIN proforma_details pd on pd.proforma_id = tps.proforma_lid ;

			update proforma_details SET status_lid = (select status_lid from temp_proforma_status),
			modified_by = (SELECT approved_by FROM temp_proforma_status),
			level = (select level from temp_proforma_status) + 1 where proforma_id = (select proforma_lid from temp_proforma_status);

		END IF;		
		
    WHEN 2 THEN 
			
			insert into proforma_status(proforma_lid,approved_by,level,status_lid,comment,file_path,tag_id)
		    select tps.proforma_lid,tps.approved_by,tps.level,tps.status_lid,tps.comment,tps.file_path,pd.tag_id
		    from temp_proforma_status tps INNER JOIN proforma_details pd on pd.proforma_id = tps.proforma_lid ;

			update proforma_details SET status_lid = (select status_lid from temp_proforma_status),
			modified_by = (SELECT approved_by FROM temp_proforma_status),
			level = (select level from temp_proforma_status) where proforma_id = (select proforma_lid from temp_proforma_status);
			
    WHEN 3 THEN
	
			insert into proforma_status(proforma_lid,approved_by,level,status_lid,comment,file_path,tag_id)
		    select tps.proforma_lid,tps.approved_by,1,tps.status_lid,tps.comment,tps.file_path,pd.tag_id
		    from temp_proforma_status tps INNER JOIN proforma_details pd on pd.proforma_id = tps.proforma_lid ;

			update proforma_details SET status_lid = (select status_lid from temp_proforma_status),
			modified_by = (SELECT approved_by FROM temp_proforma_status),
			level = 1 where proforma_id = (select proforma_lid from temp_proforma_status);
			
    WHEN 4 THEN
	
			insert into proforma_status(proforma_lid,approved_by,level,status_lid,comment,file_path,tag_id)
		    select tps.proforma_lid,tps.approved_by,tps.level,tps.status_lid,tps.comment,tps.file_path,pd.tag_id
		    from temp_proforma_status tps INNER JOIN proforma_details pd on pd.proforma_id = tps.proforma_lid ;

			update proforma_details SET status_lid = (select status_lid from temp_proforma_status),
			modified_by = (SELECT approved_by FROM temp_proforma_status),
			level = (select level from temp_proforma_status) where proforma_id = (select proforma_lid from temp_proforma_status);
	END CASE;
	

	 RETURN '{"status":200, "message":"Successfull"}';
	
	END;	
 
$_$;
 >   DROP FUNCTION public.update_proforma_status(input_json text);
       public          postgres    false                       1255    87048    update_publication(text)    FUNCTION     J  CREATE FUNCTION public.update_publication(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE 
      input_jsonb jsonb := input_json;
 BEGIN
  
  drop table if exists temp_publication;
  create table temp_publication
	(  id serial,
	   resume_achievement_lid int not NULL,
	   resume_lid int,
	   achievement_type_lid int,
	   organization_name varchar(500) ,
	   title varchar(100) not null,
	   organization_type_lid int,
	   achievement_date date ,
	   description varchar(100),
	   url_path varchar(500),
	   duration varchar(100),
	   publication_role varchar(100),
	   no_of_authors varchar(100),
	   publisher varchar(100),
	   year_of_publication varchar(200),
	   publication_url_path varchar(255), 
	   active boolean default(true) not null
	   );
	
	insert into temp_publication(resume_achievement_lid,resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration,publication_role,no_of_authors,publisher,year_of_publication,publication_url_path)
	select cast(t ->> 'resume_achievement_lid' AS integer) "resume_achievement_lid",
			cast(t ->> 'resume_lid' AS integer) "resume_lid",
		   cast(t ->> 'achievement_type_lid' AS integer) AS "achievement_type_lid",
		        t ->> 'title' AS "title",
				t ->> 'description' AS "description",
		        t ->> 'organization_name' AS "organization_name",				
		   cast(t ->> 'organization_type_lid' AS integer) AS "organization_type_lid",
		    	t ->> 'url_path' AS "url_path",
		   cast(t ->> 'achievement_date' AS date) AS "achievement_date",				
				t ->> 'duration' AS "duration",
				t ->> 'publication_role' AS "role",
				t ->> 'no_of_authors' AS "no_of_authors",
				t ->> 'publisher' AS "publisher",
				t ->> 'year_of_publication' AS "year_of_publication",
				t ->> 'publication_url_path' AS "publication_url_path"
				
	from jsonb_array_elements(input_jsonb['insert_publication']) AS t;
	

	     UPDATE resume_achievement ra SET
		 achievement_type_lid = i.achievement_type_lid,
		 title = i.title,
		 description = i.description,
		 organization_name = i.organization_name,
		 organization_type_lid = i.organization_type_lid,
		 url_path = i.url_path,
		 achievement_date = i.achievement_date,
		 duration = i.duration
		 from temp_publication i
		 where i.resume_achievement_lid = ra.resume_achievement_lid;

       IF(select publication_url_path from temp_publication) ISNULL then
		 UPDATE resume_publication p SET
		 publication_role = tp.publication_role,
		 no_of_authors = tp.no_of_authors,
		 publisher = tp.publisher,
		 year_of_publication = tp.year_of_publication
		 from temp_publication tp
		 where tp.resume_achievement_lid = p.resume_achievement_lid;
		 
	ELSE	 
	
		  UPDATE resume_publication p SET
		 publication_role = tp.publication_role,
		 no_of_authors = tp.no_of_authors,
		 publisher = tp.publisher,
		 year_of_publication = tp.year_of_publication,
		 publication_url_path = tp.publication_url_path
		 from temp_publication tp
		 where tp.resume_achievement_lid = p.resume_achievement_lid;
		 
END IF;
		  RETURN '{"status": 200, "message": "Successfull."}';

	END;
	
$$;
 :   DROP FUNCTION public.update_publication(input_json text);
       public          postgres    false                       1255    87049 "   update_qualification_details(text)    FUNCTION     ?  CREATE FUNCTION public.update_qualification_details(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
	
DECLARE 
		
	input_jsonb JSONB := input_json;
BEGIN

   drop table if exists temp_qualification;
   create TEMPORARY table temp_qualification (
    resume_qualification_lid int not null,
    resume_lid int not null,
	qualification_type_lid int not null,
	topic_of_study varchar(100),
	university varchar(100),
	institute varchar(100),
	percentile numeric(6,3),
	year_of_passing varchar(100),
	url_path varchar(100)
	
 );
 
 
 insert into temp_qualification(resume_qualification_lid,resume_lid,qualification_type_lid,topic_of_study,university,institute,percentile,year_of_passing,url_path)
 select  cast(t ->> 'resume_qualification_lid' AS integer) AS "resume_qualification_lid",
        cast(t ->> 'resume_lid' AS integer) AS "resume_lid",
        cast(t ->> 'qualification_type_lid' AS integer) AS "qualification_type_lid",
		 t ->> 'topic_of_study' AS "topic_of_study",
		 t ->> 'university' AS "university",
		 t ->> 'institute'  AS "institute",
		 cast(t ->> 'percentile' AS numeric(6,3)) AS "percentile",
		 t ->> 'year_of_passing' AS "year_of_passing",
		 t ->> 'url_path' AS "url_path"
		 
		 FROM jsonb_array_elements(input_jsonb['qualificationDetails']) AS t;
		 
    IF (select url_path from temp_qualification) ISNULL then
 update  resume_qualification rq set
		   qualification_type_lid = i.qualification_type_lid,
		   topic_of_study = i.topic_of_study,
		   university = i.university,
		   institute = i.institute,
		   percentile = i.percentile,
		   year_of_passing = i.year_of_passing
		 from temp_qualification i where i.resume_qualification_lid = rq.resume_qualification_lid;
	
ELSE	
	
		update  resume_qualification rq set
		   qualification_type_lid = i.qualification_type_lid,
		   topic_of_study = i.topic_of_study,
		   university = i.university,
		   institute = i.institute,
		   percentile = i.percentile,
		   url_path = i.url_path,
		   year_of_passing = i.year_of_passing
		 from temp_qualification i where i.resume_qualification_lid = rq.resume_qualification_lid;
	
END IF;
 RETURN '{"status": 200, "message": "Successfull."}';
	END;
$$;
 D   DROP FUNCTION public.update_qualification_details(input_json text);
       public          postgres    false                       1255    87054    update_research(text)    FUNCTION     ?
  CREATE FUNCTION public.update_research(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE 
      input_jsonb jsonb := input_json;
 BEGIN
  
  drop table if exists temp_research;
  create table temp_research
	(  id serial,
	   resume_achievement_lid int not NULL,
	   resume_lid int,
	   achievement_type_lid int,
	   organization_name varchar(500) ,
	   title varchar(100) not null,
	   organization_type_lid int,
	   achievement_date date ,
	   description varchar(100),
	   url_path varchar(500),
	   duration varchar(100),
	   volume_year varchar(100), 
	   category varchar(100), 
	   research_url_path varchar(255), 
	   active boolean default(true) not null
	   );
	
	insert into temp_research(resume_achievement_lid,resume_lid,achievement_type_lid,title,description,organization_name,organization_type_lid,url_path,achievement_date,duration,volume_year,category,research_url_path)
	select cast(t ->> 'resume_achievement_lid' AS integer) "resume_achievement_lid",
			cast(t ->> 'resume_lid' AS integer) "resume_lid",
		   cast(t ->> 'achievement_type_lid' AS integer) AS "achievement_type_lid",
		        t ->> 'title' AS "title",
				t ->> 'description' AS "description",
		        t ->> 'organization_name' AS "organization_name",				
		   cast(t ->> 'organization_type_lid' AS integer) AS "organization_type_lid",
		    	t ->> 'url_path' AS "url_path",
		   cast(t ->> 'achievement_date' AS date) AS "achievement_date",				
				t ->> 'duration' AS "duration",
				t ->> 'volume_year' AS "volume_year",
				t ->> 'category' AS "category",
				t ->> 'research_url_path' AS "research_url_path"
	from jsonb_array_elements(input_jsonb['insert_research']) AS t;
	

	     UPDATE resume_achievement ra SET
		 resume_lid = i.resume_lid,
		 achievement_type_lid = i.achievement_type_lid,
		 title = i.title,
		 description = i.description,
		 organization_name = i.organization_name,
		 organization_type_lid = i.organization_type_lid,
		 url_path = i.url_path,
		 achievement_date = i.achievement_date,
		 duration = i.duration
		 from temp_research i
		 where i.resume_achievement_lid = ra.resume_achievement_lid;

	IF(select research_url_path from temp_research ) ISNULL then	 
		 UPDATE resume_research r SET
		 volume_year = rp.volume_year,
		 category = rp.category
		 from temp_research rp
		 WHERE rp.resume_achievement_lid = r.resume_achievement_lid;
		 
	ELSE
	
		  UPDATE resume_research r SET
		 volume_year = rp.volume_year,
		 category = rp.category,
		 research_url_path = rp.research_url_path
		 from temp_research rp
		 WHERE rp.resume_achievement_lid = r.resume_achievement_lid;
END IF;

		  RETURN '{"status": 200, "message": "Successfull."}';

	END;
	
$$;
 7   DROP FUNCTION public.update_research(input_json text);
       public          postgres    false                       1255    87058    update_skill_details(text)    FUNCTION     ?  CREATE FUNCTION public.update_skill_details(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
	
DECLARE 
	input_jsonb JSONB := input_json;
BEGIN

   drop table if exists temp_skill_details;
   create TEMPORARY table temp_skill_details (
    resume_skill_selected_lid int not null,
     resume_lid  int not null,
	 skill_lid int not null 
	);
	
	insert into temp_skill_details(resume_skill_selected_lid,resume_lid,skill_lid)
	select cast(t ->> 'resume_skill_selected_lid' AS integer) AS "resume_skill_selected_lid",
	       cast(t ->> 'resume_lid' AS integer) AS "resume_lid",
	       cast(t ->> 'skill_lid' AS integer) AS "skill_lid"
		   from jsonb_array_elements(input_jsonb['skill_details_update']) AS t;
		   
     
	 	  update resume_skill_selected rs SET
		   skill_lid = i.skill_lid
		   from temp_skill_details i where i.resume_skill_selected_lid = rs.resume_skill_selected_lid;
		   
		   
	 RETURN '{"status": 200, "message": "Successfull."}';

	END;
	
$$;
 <   DROP FUNCTION public.update_skill_details(input_json text);
       public          postgres    false                       1255    87061    update_user_details(text)    FUNCTION     /  CREATE FUNCTION public.update_user_details(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

 

DECLARE

                input_jsonb JSONB := input_json;

BEGIN

 
				drop table if exists temp_user_address;
                CREATE TEMPORARY TABLE temp_user_address (

                                user_lid INTEGER NOT NULL,

                                address VARCHAR(1000) NOT NULL,

                                address_type_lid INTEGER NOT NULL,
					
					            city varchar(100),
					
					            pin_code varchar(100)

                );

               

               

               

                INSERT INTO temp_user_address(user_lid, address, address_type_lid,city,pin_code)

                SELECT CAST(t ->> 'user_lid' AS INTEGER) AS "user_lid",

       t ->> 'address' AS "address",

       CAST(t ->> 'address_type_lid' AS INTEGER) AS "address_type_lid",
	   
	       t ->> 'city' AS "city",
		   t ->> 'pin_code' AS "pin_code"

                FROM jsonb_array_elements(input_jsonb['insert_user_personal_details']['user_address']) AS t;

               

               
				drop table if exists temp_user_info;
                CREATE TEMPORARY TABLE temp_user_info(
								id serial,
                                user_lid INTEGER NOT NULL,

                                f_name varchar(100) not null,

                                l_name varchar(100) not null,

                                email varchar(100),

                                date_of_birth date,
								pancard_no varchar(100) not null,
								aadhar_card_no varchar(100),
								temp_email varchar(100),
                                gender_lid INTEGER NOT NULL,
								pancard_url_path varchar(100),	
								aadhar_card_url_path varchar(100),
								profile_url_path varchar(100),
                                nationality varchar(100)
					         
                );

               

                INSERT INTO temp_user_info(user_lid,f_name,l_name,email,date_of_birth,pancard_no,aadhar_card_no,temp_email,gender_lid,pancard_url_path,aadhar_card_url_path,profile_url_path,nationality)

                SELECT  CAST(t ->> 'user_lid' AS INTEGER) AS "user_lid",

                             t ->> 'f_name' AS "f_name",

                                                                t ->> 'l_name' AS "l_name",

                                                                t ->> 'email' AS "email",

                                                                CAST(t ->> 'date_of_birth' AS DATE) AS "date_of_birth ",
																
																t ->> 'pancard_no' AS "pancard_no",
																
																t ->> 'aadhar_card_no' AS "aadhar_card_no",
																
																t ->> 'temp_email' AS "temp_email",

                                                                CAST(t ->> 'gender_lid' AS INTEGER) AS "gender_lid",
																
																t ->> 'pancard_url_path' AS "pancard_url_path",
																
																t ->> 'aadhar_card_url_path' AS "aadhar_card_url_path",
																
																t ->> 'profile_url_path' AS "profile_url_path",

                                                                t ->> 'nationality' AS "nationality"
																
														

                    FROM jsonb_array_elements(input_jsonb['insert_user_personal_details']['user_info']) AS t;

                               
					drop table if exists temp_user_contact;
                CREATE TEMPORARY table temp_user_contact(

                                user_lid integer not null,

                                contact_number varchar(10) not null,
						
								temp_contact_number varchar(10)

                                );

                               

                INSERT INTO temp_user_contact(user_lid,contact_number,temp_contact_number)

                select  CAST(t ->> 'user_lid' AS INTEGER) AS "user_lid",

                           	  t ->> 'contact_number' AS "contact_number",

							  t ->> 'temp_contact_number' AS "temp_contact_number"
                                   FROM jsonb_array_elements(input_jsonb['insert_user_personal_details']['user_contact']) AS t;
		update user_info ui SET
				f_name = ti.f_name,
				l_name = ti.l_name,
				email = ti.email,
				date_of_birth = ti.date_of_birth,
				pancard_no = ti.pancard_no,
				aadhar_card_no = ti.aadhar_card_no,
				temp_email = ti.temp_email,
				gender_lid = ti.gender_lid,
				pancard_url_path = (
					CASE
					WHEN (SELECT pancard_url_path FROM temp_user_info WHERE id = ti.id) IS NOT NULL THEN  ti.pancard_url_path
					WHEN (SELECT pancard_url_path FROM temp_user_info) IS NULL THEN (SELECT pancard_url_path FROM user_info WHERE user_lid = ti.user_lid)
					END
					),
				aadhar_card_url_path = (
					CASE
					WHEN (SELECT aadhar_card_url_path FROM temp_user_info WHERE id = ti.id) IS NOT NULL THEN ti.aadhar_card_url_path
					WHEN (SELECT aadhar_card_url_path FROM temp_user_info) IS NULL THEN (SELECT aadhar_card_url_path FROM user_info WHERE user_lid = ti.user_lid)
					END
					),
				profile_url_path = (
				CASE
					WHEN (SELECT profile_url_path FROM temp_user_info WHERE id = ti.id) IS NOT NULL THEN ti.profile_url_path
					WHEN (SELECT profile_url_path FROM temp_user_info) IS NULL THEN (SELECT profile_url_path FROM user_info WHERE user_lid = ti.user_lid)
					END
				),
				nationality = ti.nationality				
				from temp_user_info ti 
				WHERE ti.user_lid = ui.user_lid AND ui.user_lid = ti.user_lid;
				
    
				  
--                 UPDATE  user_info ui SET
-- 				f_name = ti.f_name,
-- 				l_name = ti.l_name,
-- 				email = ti.email,
-- 				date_of_birth = ti.date_of_birth,
-- 				pancard_no = ti.pancard_no,
-- 				aadhar_card_no = ti.aadhar_card_no,
-- 				gender_lid = ti.gender_lid,
-- 				pancard_url_path = ti.pancard_url_path,
-- 				aadhar_card_url_path = ti.aadhar_card_url_path,
-- 				profile_url_path = ti.profile_url_path,
-- 				nationality = ti.nationality				
-- 				from temp_user_info ti 
-- 				WHERE ti.user_lid = ui.user_lid;
				
				
		UPDATE  user_address ua SET
				address = tu.address,
				address_type_lid = tu.address_type_lid,
				city = tu.city,
				pin_code = tu.pin_code
                FROM temp_user_address tu 
				where tu.user_lid = ua.user_lid AND ua.address_type_lid = tu.address_type_lid;
				
                UPDATE  user_contact c SET
				contact_number = uc.contact_number,
				temp_contact_number = uc.temp_contact_number
                FROM temp_user_contact uc
				WHERE uc.user_lid = c.user_lid;
						

                RETURN '{"status": 200, "message": "Successfull."}';
               

END;

$$;
 ;   DROP FUNCTION public.update_user_details(input_json text);
       public          postgres    false                       1255    87062    update_work_experience(text)    FUNCTION     ?  CREATE FUNCTION public.update_work_experience(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE 
input_jsonb jsonb := input_json;
		
BEGIN
    drop table if exists temp_work;
    create  temporary table temp_work(
   	resume_experience_lid int not null,
	resume_lid int not null ,
	experience_type_lid int not null,
	employer_name varchar(100) not null,
	designation varchar(100) not null,
	designation_lid int,
	description varchar(500) not null,
	start_date date not null,
	end_date date not null,
	responsibilities varchar(100) not null,
    is_current boolean,
	duration varchar(100),
	padagogy varchar(100)
	);
	
	
insert into temp_work(resume_experience_lid,resume_lid,experience_type_lid,employer_name,designation,designation_lid,description,start_date,end_date,responsibilities,is_current,duration,padagogy)
select cast(t ->> 'resume_experience_lid' AS integer) AS "resume_experience_lid",
	   cast(t ->> 'resume_lid' AS integer) AS "resume_lid",
       cast(t ->> 'experience_type_lid' AS integer) AS "experience_type_lid",
	        t ->> 'employer_name' AS "employer_name",
			t ->> 'designation' AS "designation",
	   cast(t ->> 'designation_lid' AS integer) AS "designation_lid",
	        t ->> 'description' AS "description",
	   cast(t ->> 'start_date' AS date) "start_date",
	   cast(t ->> 'end_date' AS date) AS "end_date",
	        t ->> 'responsibilities' AS "responsibilities",
       cast(t ->> 'is_current' AS boolean) AS "is_current",
		    t ->> 'duration' AS "duration",
			t ->> 'padagogy' AS "padagogy"		  
      
FROM jsonb_array_elements(input_jsonb['work_Experience_update']) AS t;
	   
update resume_experience p set 
	        experience_type_lid = i.experience_type_lid,
			employer_name = i.employer_name,
			designation = i.designation,
			designation_lid = i.designation_lid,
			description = i.description,
			start_date = i.start_date,
			end_date = i.end_date,
			responsibilities = i.responsibilities,
            is_current = i.is_current,
			duration = i.duration,
			padagogy = i.padagogy
			from temp_work i where i.resume_experience_lid = p.resume_experience_lid;
				 
	 
RETURN '{"status": 200, "message": "Successfull."}';
END;	
$$;
 >   DROP FUNCTION public.update_work_experience(input_json text);
       public          postgres    false                       1255    87063    upsert_proforma_details(text)    FUNCTION     [  CREATE FUNCTION public.upsert_proforma_details(input_json text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$

DECLARE
input_jsonb JSONB := input_json;
BEGIN

-- DO $$
-- 	DECLARE input_jsonb JSONB:= '{
-- 	  "insert_proforma": [
-- 	    {
-- 	      "application_lid": "149",
-- 	      "proforma_id": "14",
-- 	      "module_name": "New Maths",
-- 	      "module_id": "",
--   	      "vf_module_id": "",
-- 	      "teaching_hours": "5",
-- 	      "program_name": "Bachelor of Science",
-- 	      "program_id": "59876432",
-- 	      "acad_session": "Semester I",
-- 	      "commencement_date_of_program": "2222-02-22",
-- 	      "rate_per_hours": "2500",
-- 	      "total_no_of_hrs_alloted": "60",
-- 	      "no_of_division": "4",
-- 	      "student_count_per_division": "60",
-- 	      "aol_obe": "OBL",
-- 	      "level": 1,
-- 	      "status_lid": 1,
--           "username": "KAPIL"
-- 	    },
-- 	    {
-- 	      "application_lid": "149",
-- 	      "proforma_id": "15",
-- 	      "module_name": "Physics",
-- 	      "module_id": "89745854",
--   	      "vf_module_id": "",
-- 	      "teaching_hours": "5",
-- 	      "program_name": "Bachelor of Science",
-- 	      "program_id": "59876432",
-- 	      "acad_session": "Semester I",
-- 	      "commencement_date_of_program": "2222-02-22",
-- 	      "rate_per_hours": "2500",
-- 	      "total_no_of_hrs_alloted": "60",
-- 	      "no_of_division": "4",
-- 	      "student_count_per_division": "60",
-- 	      "aol_obe": "OBL",
-- 	      "level": 1,
-- 	      "status_lid": 1,
--           "username": "KAPIL"
-- 	    },
-- 	    {
-- 	      "application_lid": "149",
-- 	      "proforma_id": "27",
-- 	      "module_name": "Biology",
-- 	      "module_id": "",
--   	      "vf_module_id": "",
-- 	      "teaching_hours": "5",
-- 	      "program_name": "Bachelor of Science",
-- 	      "program_id": "59876432",
-- 	      "acad_session": "Semester I",
-- 	      "commencement_date_of_program": "2222-02-22",
-- 	      "rate_per_hours": "2500",
-- 	      "total_no_of_hrs_alloted": "60",
-- 	      "no_of_division": "4",
-- 	      "student_count_per_division": "60",
-- 	      "aol_obe": "OBL",
-- 	      "level": 1,
-- 	      "status_lid": 1,
--           "username": "KAPIL"
-- 	    }
-- 	  ]
-- 	}';
	
	DROP TABLE IF EXISTS temp_proforma_details; CREATE TEMPORARY TABLE temp_proforma_details(
		id serial,
		application_lid INT NOT NULL,
		proforma_id INT,
		module_name VARCHAR(500),
		module_id VARCHAR(20),
		vf_module_id INT,
		teaching_hours VARCHAR(50),
		program_name VARCHAR(500),
		program_id varchar(100) NOT NULL,
		acad_session VARCHAR(100),
		commencement_date_of_program DATE,
		rate_per_hours INT,
		total_no_of_hrs_alloted INT,
		no_of_division INT,
		student_count_per_division INT,
		aol_obe VARCHAR(20),
		created_by VARCHAR(100),
		created_date TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
		level INT,
		status_lid INT,
		last_modified_date TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      username VARCHAR(255),
		active boolean NOT NULL DEFAULT(true)
	); INSERT INTO temp_proforma_details(application_lid, proforma_id, module_name, module_id, vf_module_id, teaching_hours, program_name, program_id, acad_session, commencement_date_of_program, rate_per_hours, total_no_of_hrs_alloted, no_of_division, student_count_per_division, aol_obe, level, status_lid, username)
	SELECT 
		   CAST(t ->> 'application_lid' AS INT),
		   CAST(IIF(t ->> 'proforma_id' = '', NULL, t ->> 'proforma_id') AS INT),
	           t ->> 'module_name',
	           IIF(t ->> 'module_id' = '', NULL, t ->> 'module_id'),
	       CAST(IIF(t ->> 'vf_module_id' = '', NULL, t ->> 'vf_module_id') AS INT),
		        t ->> 'teaching_hours',
		        t ->> 'program_name',
		        t ->> 'program_id',
		        t ->> 'acad_session',
		   CAST(t ->> 'commencement_date_of_program' AS DATE),
		   CAST(t ->> 'rate_per_hours' AS INT),
		   CAST(t ->> 'total_no_of_hrs_alloted' AS INT),
		   CAST(t ->> 'no_of_division' AS INT),
		   CAST(t ->> 'student_count_per_division' AS INT),
	            t ->> 'aol_obe',
		   CAST(t ->> 'level' AS INT),
		   CAST(t ->> 'status_lid' AS INT),
                t ->> 'username'
	FROM jsonb_array_elements(input_jsonb['insert_proforma']) AS t; -- TRUNCATE TABLE modules RESTART IDENTITY
	-- SELECT * FROM temp_proforma_details;
	-- SELECT * FROM modules;

    WITH cte AS (	
        INSERT INTO modules(module_id, name, program_name, program_id, acad_session, tmp_proforma_id)
        SELECT p.module_id, p.module_name, p.program_name, p.program_id, p.acad_session, p.id FROM temp_proforma_details p
        WHERE p.module_id IS NULL AND p.vf_module_id IS NULL
        RETURNING id, tmp_proforma_id
    )
    UPDATE temp_proforma_details p SET vf_module_id = cte.id
    FROM cte WHERE cte.tmp_proforma_id = p.id; UPDATE proforma_details pd SET
   module = tpd.module_name,
   module_id = tpd.module_id,
   vf_module_id = tpd.vf_module_id,
   teaching_hours = tpd.teaching_hours,
   program_name = tpd.program_name,
   program_id = tpd.program_id,
   acad_session = tpd.acad_session,
   commencement_date_of_program = tpd.commencement_date_of_program,
   rate_per_hours = tpd.rate_per_hours,
   total_no_of_hrs_alloted = tpd.total_no_of_hrs_alloted,
   no_of_division = tpd.no_of_division,
   student_count_per_division = tpd.student_count_per_division,
   aol_obe = tpd.aol_obe,
   modified_by = tpd.username
   FROM temp_proforma_details tpd WHERE pd.proforma_id = tpd.proforma_id; 

   
   INSERT INTO proforma_details(application_lid, module, teaching_hours, program_id, acad_session, commencement_date_of_program , rate_per_hours, 
   total_no_of_hrs_alloted, no_of_division,status_lid,student_count_per_division, aol_obe, created_by, program_name, module_id, vf_module_id, level )
   SELECT application_lid, module_name, teaching_hours, program_id, acad_session, commencement_date_of_program , rate_per_hours, 
   total_no_of_hrs_alloted, no_of_division,status_lid, student_count_per_division, aol_obe, username, program_name, module_id, vf_module_id, level 
   FROM temp_proforma_details
   WHERE proforma_id IS NULL; 
   
   RETURN '{"status":200, "message":"Successfull"}';
--           END 
-- 	$$
	END; 
$_$;
 ?   DROP FUNCTION public.upsert_proforma_details(input_json text);
       public          postgres    false            `           1259    87064    achievement_type    TABLE     ?   CREATE TABLE public.achievement_type (
    id integer NOT NULL,
    name character varying(30),
    description character varying(100),
    parent_lid integer,
    active boolean DEFAULT true NOT NULL,
    abbr character varying(30)
);
 $   DROP TABLE public.achievement_type;
       public         heap    postgres    false            a           1259    87068    achievement_type_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.achievement_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.achievement_type_id_seq;
       public          postgres    false    352            ?           0    0    achievement_type_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.achievement_type_id_seq OWNED BY public.achievement_type.id;
          public          postgres    false    353            b           1259    87069    address_type    TABLE     ?   CREATE TABLE public.address_type (
    id integer NOT NULL,
    name character varying(50),
    active boolean DEFAULT true NOT NULL
);
     DROP TABLE public.address_type;
       public         heap    postgres    false            c           1259    87073    address_type_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.address_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.address_type_id_seq;
       public          postgres    false    354            ?           0    0    address_type_id_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE public.address_type_id_seq OWNED BY public.address_type.id;
          public          postgres    false    355            d           1259    87074    admin_organization    TABLE     ?   CREATE TABLE public.admin_organization (
    id integer NOT NULL,
    user_lid integer,
    organization_lid character varying,
    active boolean DEFAULT true NOT NULL
);
 &   DROP TABLE public.admin_organization;
       public         heap    postgres    false            e           1259    87080    admin_organization_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.admin_organization_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.admin_organization_id_seq;
       public          postgres    false    356            ?           0    0    admin_organization_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.admin_organization_id_seq OWNED BY public.admin_organization.id;
          public          postgres    false    357            f           1259    87081    app_url    TABLE     ?   CREATE TABLE public.app_url (
    id integer NOT NULL,
    name character varying(20) NOT NULL,
    tag character varying(25),
    path_name character varying(50),
    parent_lid integer,
    active boolean DEFAULT true NOT NULL
);
    DROP TABLE public.app_url;
       public         heap    postgres    false            g           1259    87085    app_url_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.app_url_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE public.app_url_id_seq;
       public          postgres    false    358            ?           0    0    app_url_id_seq    SEQUENCE OWNED BY     A   ALTER SEQUENCE public.app_url_id_seq OWNED BY public.app_url.id;
          public          postgres    false    359            h           1259    87086    application_bank_details    TABLE     ?  CREATE TABLE public.application_bank_details (
    rev_number integer NOT NULL,
    rev_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    user_lid integer NOT NULL,
    bank_account_type_lid integer,
    resume_lid integer NOT NULL,
    bank_name character varying(100) NOT NULL,
    branch_name character varying(100),
    ifsc_code character varying(100),
    micr_code character varying(20),
    account_number character varying(100),
    url_path character varying(200),
    active boolean DEFAULT true NOT NULL,
    application_lid bigint
);
 ,   DROP TABLE public.application_bank_details;
       public         heap    postgres    false            i           1259    87093 '   application_bank_details_rev_number_seq    SEQUENCE     ?   CREATE SEQUENCE public.application_bank_details_rev_number_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 >   DROP SEQUENCE public.application_bank_details_rev_number_seq;
       public          postgres    false    360            ?           0    0 '   application_bank_details_rev_number_seq    SEQUENCE OWNED BY     s   ALTER SEQUENCE public.application_bank_details_rev_number_seq OWNED BY public.application_bank_details.rev_number;
          public          postgres    false    361            j           1259    87094    application_resume_achievement    TABLE     _  CREATE TABLE public.application_resume_achievement (
    rev_number integer NOT NULL,
    rev_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    resume_achievement_lid integer NOT NULL,
    resume_lid integer NOT NULL,
    achievement_type_lid integer,
    title character varying(100),
    description character varying(255),
    organization_name character varying(300),
    organization_type_lid integer,
    url_path character varying(300),
    achievement_date date,
    duration character varying(20),
    active boolean DEFAULT true NOT NULL,
    application_lid bigint
);
 2   DROP TABLE public.application_resume_achievement;
       public         heap    postgres    false            k           1259    87101 -   application_resume_achievement_rev_number_seq    SEQUENCE     ?   CREATE SEQUENCE public.application_resume_achievement_rev_number_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 D   DROP SEQUENCE public.application_resume_achievement_rev_number_seq;
       public          postgres    false    362            ?           0    0 -   application_resume_achievement_rev_number_seq    SEQUENCE OWNED BY        ALTER SEQUENCE public.application_resume_achievement_rev_number_seq OWNED BY public.application_resume_achievement.rev_number;
          public          postgres    false    363            l           1259    87102    application_resume_experience    TABLE       CREATE TABLE public.application_resume_experience (
    rev_number integer NOT NULL,
    rev_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    resume_experience_lid integer NOT NULL,
    resume_lid integer NOT NULL,
    experience_type_lid integer,
    employer_name character varying(255) NOT NULL,
    designation character varying(40),
    designation_lid integer,
    description character varying(500),
    start_date date NOT NULL,
    end_date date NOT NULL,
    responsibilities character varying(255),
    is_current boolean,
    active boolean DEFAULT true NOT NULL,
    duration character varying(100),
    padagogy character varying(100),
    application_lid bigint,
    CONSTRAINT start_end_date_check CHECK ((start_date <= end_date))
);
 1   DROP TABLE public.application_resume_experience;
       public         heap    postgres    false            m           1259    87110 ,   application_resume_experience_rev_number_seq    SEQUENCE     ?   CREATE SEQUENCE public.application_resume_experience_rev_number_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 C   DROP SEQUENCE public.application_resume_experience_rev_number_seq;
       public          postgres    false    364            ?           0    0 ,   application_resume_experience_rev_number_seq    SEQUENCE OWNED BY     }   ALTER SEQUENCE public.application_resume_experience_rev_number_seq OWNED BY public.application_resume_experience.rev_number;
          public          postgres    false    365            n           1259    87111    application_resume_publication    TABLE     &  CREATE TABLE public.application_resume_publication (
    rev_number integer NOT NULL,
    rev_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    resume_publication_lid integer NOT NULL,
    resume_achievement_lid integer NOT NULL,
    publication_role character varying(100),
    no_of_authors character varying(100),
    publisher character varying(50),
    year_of_publication character varying(50),
    publication_url_path character varying(200),
    active boolean DEFAULT true NOT NULL,
    application_lid bigint
);
 2   DROP TABLE public.application_resume_publication;
       public         heap    postgres    false            o           1259    87118 -   application_resume_publication_rev_number_seq    SEQUENCE     ?   CREATE SEQUENCE public.application_resume_publication_rev_number_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 D   DROP SEQUENCE public.application_resume_publication_rev_number_seq;
       public          postgres    false    366            ?           0    0 -   application_resume_publication_rev_number_seq    SEQUENCE OWNED BY        ALTER SEQUENCE public.application_resume_publication_rev_number_seq OWNED BY public.application_resume_publication.rev_number;
          public          postgres    false    367            p           1259    87119     application_resume_qualification    TABLE     \  CREATE TABLE public.application_resume_qualification (
    id integer NOT NULL,
    rev_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    resume_qualification_lid integer NOT NULL,
    resume_lid integer NOT NULL,
    qualification_type_lid integer,
    topic_of_study character varying(50),
    university character varying(100),
    institute character varying(100),
    percentile numeric(6,3),
    year_of_passing character varying(20),
    url_path character varying(200),
    active boolean DEFAULT true NOT NULL,
    is_completed boolean,
    application_lid bigint
);
 4   DROP TABLE public.application_resume_qualification;
       public         heap    postgres    false            q           1259    87124 /   application_resume_qualification_rev_number_seq    SEQUENCE     ?   CREATE SEQUENCE public.application_resume_qualification_rev_number_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 F   DROP SEQUENCE public.application_resume_qualification_rev_number_seq;
       public          postgres    false    368            ?           0    0 /   application_resume_qualification_rev_number_seq    SEQUENCE OWNED BY     {   ALTER SEQUENCE public.application_resume_qualification_rev_number_seq OWNED BY public.application_resume_qualification.id;
          public          postgres    false    369            r           1259    87125    application_resume_research    TABLE     ?  CREATE TABLE public.application_resume_research (
    rev_number integer NOT NULL,
    rev_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    resume_research_lid integer NOT NULL,
    resume_achievement_lid integer NOT NULL,
    volume_year character varying(100),
    description character varying(500),
    category character varying(100),
    research_url_path character varying(200),
    active boolean DEFAULT true NOT NULL,
    application_lid bigint
);
 /   DROP TABLE public.application_resume_research;
       public         heap    postgres    false            s           1259    87132 *   application_resume_research_rev_number_seq    SEQUENCE     ?   CREATE SEQUENCE public.application_resume_research_rev_number_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 A   DROP SEQUENCE public.application_resume_research_rev_number_seq;
       public          postgres    false    370            ?           0    0 *   application_resume_research_rev_number_seq    SEQUENCE OWNED BY     y   ALTER SEQUENCE public.application_resume_research_rev_number_seq OWNED BY public.application_resume_research.rev_number;
          public          postgres    false    371            t           1259    87133 !   application_resume_skill_selected    TABLE     [  CREATE TABLE public.application_resume_skill_selected (
    rev_number integer NOT NULL,
    rev_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    resume_skill_selected_lid integer NOT NULL,
    resume_lid integer NOT NULL,
    skill_lid integer,
    active boolean DEFAULT true NOT NULL,
    application_lid bigint
);
 5   DROP TABLE public.application_resume_skill_selected;
       public         heap    postgres    false            u           1259    87138 0   application_resume_skill_selected_rev_number_seq    SEQUENCE     ?   CREATE SEQUENCE public.application_resume_skill_selected_rev_number_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 G   DROP SEQUENCE public.application_resume_skill_selected_rev_number_seq;
       public          postgres    false    372            ?           0    0 0   application_resume_skill_selected_rev_number_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE public.application_resume_skill_selected_rev_number_seq OWNED BY public.application_resume_skill_selected.rev_number;
          public          postgres    false    373            v           1259    87139    application_status    TABLE     ?   CREATE TABLE public.application_status (
    id integer NOT NULL,
    name character varying(20),
    active boolean DEFAULT true NOT NULL
);
 &   DROP TABLE public.application_status;
       public         heap    postgres    false            w           1259    87143    application_status_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.application_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.application_status_id_seq;
       public          postgres    false    374            ?           0    0    application_status_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.application_status_id_seq OWNED BY public.application_status.id;
          public          postgres    false    375            x           1259    87144    application_user_address    TABLE     ?  CREATE TABLE public.application_user_address (
    rev_number integer NOT NULL,
    rev_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    user_lid integer NOT NULL,
    address character varying(550),
    address_type_lid integer,
    city character varying(100),
    pin_code character varying(100),
    active boolean DEFAULT true NOT NULL,
    resume_lid integer,
    application_lid integer
);
 ,   DROP TABLE public.application_user_address;
       public         heap    postgres    false            y           1259    87151 '   application_user_address_rev_number_seq    SEQUENCE     ?   CREATE SEQUENCE public.application_user_address_rev_number_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 >   DROP SEQUENCE public.application_user_address_rev_number_seq;
       public          postgres    false    376            ?           0    0 '   application_user_address_rev_number_seq    SEQUENCE OWNED BY     s   ALTER SEQUENCE public.application_user_address_rev_number_seq OWNED BY public.application_user_address.rev_number;
          public          postgres    false    377            z           1259    87152    application_user_contact    TABLE     z  CREATE TABLE public.application_user_contact (
    rev_number integer NOT NULL,
    rev_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    user_lid integer NOT NULL,
    contact_number character varying(10),
    temp_contact_number character varying(10),
    active boolean DEFAULT true NOT NULL,
    resume_lid integer,
    application_lid bigint
);
 ,   DROP TABLE public.application_user_contact;
       public         heap    postgres    false            {           1259    87157 '   application_user_contact_rev_number_seq    SEQUENCE     ?   CREATE SEQUENCE public.application_user_contact_rev_number_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 >   DROP SEQUENCE public.application_user_contact_rev_number_seq;
       public          postgres    false    378            ?           0    0 '   application_user_contact_rev_number_seq    SEQUENCE OWNED BY     s   ALTER SEQUENCE public.application_user_contact_rev_number_seq OWNED BY public.application_user_contact.rev_number;
          public          postgres    false    379            |           1259    87158    application_user_info    TABLE     ?  CREATE TABLE public.application_user_info (
    rev_number integer NOT NULL,
    rev_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    user_lid integer NOT NULL,
    email character varying(150),
    f_name character varying(100),
    l_name character varying(100),
    date_of_birth date,
    pancard_no character varying(15),
    aadhar_card_no character varying(15),
    temp_email character varying(150),
    gender_lid integer,
    pancard_url_path character varying(255),
    profile_url_path character varying(255),
    aadhar_card_url_path character varying(255),
    nationality character varying(100),
    active boolean DEFAULT true,
    resume_lid integer,
    application_lid bigint
);
 )   DROP TABLE public.application_user_info;
       public         heap    postgres    false            }           1259    87165 $   application_user_info_rev_number_seq    SEQUENCE     ?   CREATE SEQUENCE public.application_user_info_rev_number_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE public.application_user_info_rev_number_seq;
       public          postgres    false    380            ?           0    0 $   application_user_info_rev_number_seq    SEQUENCE OWNED BY     m   ALTER SEQUENCE public.application_user_info_rev_number_seq OWNED BY public.application_user_info.rev_number;
          public          postgres    false    381            ~           1259    87166    approved_faculty_status    TABLE       CREATE TABLE public.approved_faculty_status (
    id integer NOT NULL,
    proforma_lid integer,
    created_by character varying(255),
    created_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    is_discontinued boolean DEFAULT false NOT NULL
);
 +   DROP TABLE public.approved_faculty_status;
       public         heap    postgres    false                       1259    87171    approved_faculty_status_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.approved_faculty_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 5   DROP SEQUENCE public.approved_faculty_status_id_seq;
       public          postgres    false    382            ?           0    0    approved_faculty_status_id_seq    SEQUENCE OWNED BY     a   ALTER SEQUENCE public.approved_faculty_status_id_seq OWNED BY public.approved_faculty_status.id;
          public          postgres    false    383            ?           1259    87172    bank_account_type    TABLE     ?   CREATE TABLE public.bank_account_type (
    id integer NOT NULL,
    account_type character varying(100) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    abbr character varying(30)
);
 %   DROP TABLE public.bank_account_type;
       public         heap    postgres    false            ?           1259    87176    bank_account_type_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.bank_account_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.bank_account_type_id_seq;
       public          postgres    false    384            ?           0    0    bank_account_type_id_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.bank_account_type_id_seq OWNED BY public.bank_account_type.id;
          public          postgres    false    385            ?           1259    87177    bank_details    TABLE     ?  CREATE TABLE public.bank_details (
    user_lid integer NOT NULL,
    bank_account_type_lid integer NOT NULL,
    resume_lid integer,
    bank_name character varying(100) NOT NULL,
    branch_name character varying(100) NOT NULL,
    ifsc_code character varying(100) NOT NULL,
    micr_code character varying(20),
    account_number character varying(100) NOT NULL,
    url_path character varying(200) NOT NULL,
    active boolean DEFAULT true NOT NULL
);
     DROP TABLE public.bank_details;
       public         heap    postgres    false            ?           1259    87183    campus    TABLE       CREATE TABLE public.campus (
    id integer NOT NULL,
    campus_id character varying(20) NOT NULL,
    abbr character varying(20),
    name character varying(100) NOT NULL,
    description character varying(200),
    active boolean DEFAULT true NOT NULL
);
    DROP TABLE public.campus;
       public         heap    postgres    false            ?           1259    87187    campus_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.campus_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE public.campus_id_seq;
       public          postgres    false    387            ?           0    0    campus_id_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE public.campus_id_seq OWNED BY public.campus.id;
          public          postgres    false    388            ?           1259    87188    designation    TABLE     ?   CREATE TABLE public.designation (
    id integer NOT NULL,
    name character varying(50),
    points numeric(6,3),
    active boolean DEFAULT true NOT NULL
);
    DROP TABLE public.designation;
       public         heap    postgres    false            ?           1259    87192    designation_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.designation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.designation_id_seq;
       public          postgres    false    389            ?           0    0    designation_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.designation_id_seq OWNED BY public.designation.id;
          public          postgres    false    390            ?           1259    87193    discontinue_details    TABLE     U  CREATE TABLE public.discontinue_details (
    id integer NOT NULL,
    proforma_lid integer,
    organization_lid character varying,
    comment character varying(255),
    created_by character varying(255),
    created_date timestamp without time zone DEFAULT now(),
    active boolean DEFAULT true NOT NULL,
    is_discontinued boolean
);
 '   DROP TABLE public.discontinue_details;
       public         heap    postgres    false            ?           1259    87199    discontinue_details_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.discontinue_details_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.discontinue_details_id_seq;
       public          postgres    false    391            ?           0    0    discontinue_details_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.discontinue_details_id_seq OWNED BY public.discontinue_details.id;
          public          postgres    false    392            ?           1259    87200    experience_type    TABLE       CREATE TABLE public.experience_type (
    id integer NOT NULL,
    name character varying(30),
    description character varying(100),
    parent_lid integer,
    active boolean DEFAULT true NOT NULL,
    points numeric(6,3),
    abbr character varying(30)
);
 #   DROP TABLE public.experience_type;
       public         heap    postgres    false            ?           1259    87204    experience_type_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.experience_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.experience_type_id_seq;
       public          postgres    false    393            ?           0    0    experience_type_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE public.experience_type_id_seq OWNED BY public.experience_type.id;
          public          postgres    false    394            ?           1259    87205    http_method    TABLE     ?   CREATE TABLE public.http_method (
    id integer NOT NULL,
    name character varying(20),
    method_name character varying(10),
    active boolean DEFAULT true NOT NULL
);
    DROP TABLE public.http_method;
       public         heap    postgres    false            ?           1259    87209    http_method_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.http_method_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.http_method_id_seq;
       public          postgres    false    395            ?           0    0    http_method_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.http_method_id_seq OWNED BY public.http_method.id;
          public          postgres    false    396            ?           1259    87210    level    TABLE     `   CREATE TABLE public.level (
    id integer NOT NULL,
    role_lid integer,
    level integer
);
    DROP TABLE public.level;
       public         heap    postgres    false            ?           1259    87213    level_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.level_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE public.level_id_seq;
       public          postgres    false    397            ?           0    0    level_id_seq    SEQUENCE OWNED BY     =   ALTER SEQUENCE public.level_id_seq OWNED BY public.level.id;
          public          postgres    false    398            ?           1259    87214    modules    TABLE     5  CREATE TABLE public.modules (
    id integer NOT NULL,
    module_id character varying(20),
    name character varying(500),
    program_name character varying(500),
    program_id character varying(20),
    acad_session character varying(100),
    tmp_proforma_id integer,
    active boolean DEFAULT true
);
    DROP TABLE public.modules;
       public         heap    postgres    false            ?           1259    87220    modules_id_seq    SEQUENCE     ?   ALTER TABLE public.modules ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.modules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    399            ?           1259    128295    offer_letter_details    TABLE     =  CREATE TABLE public.offer_letter_details (
    id integer NOT NULL,
    proforma_id integer NOT NULL,
    status integer,
    reason character varying(255),
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by character varying(255),
    approved_by character varying(255)
);
 (   DROP TABLE public.offer_letter_details;
       public         heap    postgres    false            ?           1259    128294    offer_letter_details_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.offer_letter_details_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.offer_letter_details_id_seq;
       public          postgres    false    451            ?           0    0    offer_letter_details_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.offer_letter_details_id_seq OWNED BY public.offer_letter_details.id;
          public          postgres    false    450            ?           1259    87221    organization    TABLE     '  CREATE TABLE public.organization (
    id integer NOT NULL,
    organization_id character varying(100) NOT NULL,
    abbr character varying(20),
    name character varying(255) NOT NULL,
    description character varying(255),
    campus_lid integer,
    active boolean DEFAULT true NOT NULL
);
     DROP TABLE public.organization;
       public         heap    postgres    false            ?           1259    87227    organization_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.organization_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.organization_id_seq;
       public          postgres    false    401            ?           0    0    organization_id_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE public.organization_id_seq OWNED BY public.organization.id;
          public          postgres    false    402            ?           1259    87228    organization_type    TABLE     ?   CREATE TABLE public.organization_type (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    description character varying(255),
    active boolean DEFAULT true NOT NULL,
    abbr character varying(30)
);
 %   DROP TABLE public.organization_type;
       public         heap    postgres    false            ?           1259    87232    organization_type_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.organization_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.organization_type_id_seq;
       public          postgres    false    403            ?           0    0    organization_type_id_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.organization_type_id_seq OWNED BY public.organization_type.id;
          public          postgres    false    404            ?           1259    87233    profile_category_settings    TABLE     ?   CREATE TABLE public.profile_category_settings (
    id integer NOT NULL,
    profile_category_id integer,
    range_start numeric(5,2),
    range_end numeric(5,2),
    range_point numeric(5,2),
    active boolean DEFAULT true NOT NULL
);
 -   DROP TABLE public.profile_category_settings;
       public         heap    postgres    false            ?           1259    87237     profile_category_settings_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.profile_category_settings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public.profile_category_settings_id_seq;
       public          postgres    false    405            ?           0    0     profile_category_settings_id_seq    SEQUENCE OWNED BY     e   ALTER SEQUENCE public.profile_category_settings_id_seq OWNED BY public.profile_category_settings.id;
          public          postgres    false    406            ?           1259    87238    proforma_details    TABLE     ?  CREATE TABLE public.proforma_details (
    proforma_id integer NOT NULL,
    application_lid integer NOT NULL,
    module character varying,
    teaching_hours character varying(50),
    program_id character varying(100) NOT NULL,
    acad_session character varying(100),
    commencement_date_of_program date,
    rate_per_hours integer,
    total_no_of_hrs_alloted integer,
    no_of_division integer,
    student_count_per_division integer,
    aol_obe character varying,
    created_by character varying(100),
    created_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    level integer NOT NULL,
    status_lid integer,
    tag_id integer DEFAULT 0 NOT NULL,
    last_modified_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    active boolean DEFAULT true NOT NULL,
    program_name character varying(100),
    module_id character varying(100),
    vf_module_id integer,
    modified_by character varying(255)
);
 $   DROP TABLE public.proforma_details;
       public         heap    postgres    false            ?           1259    87247     proforma_details_proforma_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.proforma_details_proforma_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public.proforma_details_proforma_id_seq;
       public          postgres    false    407            ?           0    0     proforma_details_proforma_id_seq    SEQUENCE OWNED BY     e   ALTER SEQUENCE public.proforma_details_proforma_id_seq OWNED BY public.proforma_details.proforma_id;
          public          postgres    false    408            ?           1259    87248    proforma_status    TABLE     ?  CREATE TABLE public.proforma_status (
    id integer NOT NULL,
    proforma_lid integer,
    approved_by character varying(100),
    level integer,
    status_lid integer,
    comment character varying(255),
    created_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    file_path character varying(255),
    tag_id integer,
    active boolean DEFAULT true NOT NULL
);
 #   DROP TABLE public.proforma_status;
       public         heap    postgres    false            ?           1259    87255    proforma_status_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.proforma_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.proforma_status_id_seq;
       public          postgres    false    409            ?           0    0    proforma_status_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE public.proforma_status_id_seq OWNED BY public.proforma_status.id;
          public          postgres    false    410            ?           1259    87256    qualification_type    TABLE     ?   CREATE TABLE public.qualification_type (
    id integer NOT NULL,
    name character varying(30),
    description character varying(100),
    parent_lid integer,
    active boolean DEFAULT true NOT NULL,
    abbr character varying(100)
);
 &   DROP TABLE public.qualification_type;
       public         heap    postgres    false            ?           1259    87260    qualification_type_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.qualification_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.qualification_type_id_seq;
       public          postgres    false    411            ?           0    0    qualification_type_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.qualification_type_id_seq OWNED BY public.qualification_type.id;
          public          postgres    false    412            ?           1259    87261    resume    TABLE     V  CREATE TABLE public.resume (
    id integer NOT NULL,
    user_lid integer,
    name character varying(30),
    description character varying(100),
    created_by integer,
    active boolean DEFAULT true NOT NULL,
    last_modified_by character varying(255),
    created_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
    DROP TABLE public.resume;
       public         heap    postgres    false            ?           1259    87266    resume_achievement    TABLE     ?  CREATE TABLE public.resume_achievement (
    resume_achievement_lid integer NOT NULL,
    resume_lid integer,
    achievement_type_lid integer,
    title character varying(100) NOT NULL,
    description character varying(255),
    organization_name character varying(300),
    organization_type_lid integer,
    url_path character varying(300),
    achievement_date date,
    duration character varying(20),
    active boolean DEFAULT true NOT NULL,
    application_lid bigint
);
 &   DROP TABLE public.resume_achievement;
       public         heap    postgres    false            ?           1259    87272 -   resume_achievement_resume_achievement_lid_seq    SEQUENCE     ?   CREATE SEQUENCE public.resume_achievement_resume_achievement_lid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 D   DROP SEQUENCE public.resume_achievement_resume_achievement_lid_seq;
       public          postgres    false    414            ?           0    0 -   resume_achievement_resume_achievement_lid_seq    SEQUENCE OWNED BY        ALTER SEQUENCE public.resume_achievement_resume_achievement_lid_seq OWNED BY public.resume_achievement.resume_achievement_lid;
          public          postgres    false    415            ?           1259    87273    resume_experience    TABLE     e  CREATE TABLE public.resume_experience (
    resume_experience_lid integer NOT NULL,
    resume_lid integer,
    experience_type_lid integer,
    employer_name character varying(255) NOT NULL,
    designation character varying(40) NOT NULL,
    designation_lid integer NOT NULL,
    description character varying(500),
    start_date date NOT NULL,
    end_date date NOT NULL,
    responsibilities character varying(255),
    is_current boolean DEFAULT true NOT NULL,
    active boolean DEFAULT true NOT NULL,
    duration character varying(100),
    padagogy character varying(100),
    application_lid bigint
);
 %   DROP TABLE public.resume_experience;
       public         heap    postgres    false            ?           1259    87280 +   resume_experience_resume_experience_lid_seq    SEQUENCE     ?   CREATE SEQUENCE public.resume_experience_resume_experience_lid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 B   DROP SEQUENCE public.resume_experience_resume_experience_lid_seq;
       public          postgres    false    416            ?           0    0 +   resume_experience_resume_experience_lid_seq    SEQUENCE OWNED BY     {   ALTER SEQUENCE public.resume_experience_resume_experience_lid_seq OWNED BY public.resume_experience.resume_experience_lid;
          public          postgres    false    417            ?           1259    87281    resume_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.resume_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE public.resume_id_seq;
       public          postgres    false    413            ?           0    0    resume_id_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE public.resume_id_seq OWNED BY public.resume.id;
          public          postgres    false    418            ?           1259    87282    resume_profile_category    TABLE     ?  CREATE TABLE public.resume_profile_category (
    id integer NOT NULL,
    name character varying(100),
    description character varying(100),
    max_points numeric(6,3),
    parent_lid integer,
    table_name character varying(100),
    foreign_lid integer,
    active boolean DEFAULT true NOT NULL,
    json_tag character varying(100),
    tag_name character varying(50),
    max_limit integer
);
 +   DROP TABLE public.resume_profile_category;
       public         heap    postgres    false            ?           1259    87286    resume_profile_category_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.resume_profile_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 5   DROP SEQUENCE public.resume_profile_category_id_seq;
       public          postgres    false    419            ?           0    0    resume_profile_category_id_seq    SEQUENCE OWNED BY     a   ALTER SEQUENCE public.resume_profile_category_id_seq OWNED BY public.resume_profile_category.id;
          public          postgres    false    420            ?           1259    87287    resume_publication    TABLE     ?  CREATE TABLE public.resume_publication (
    resume_publication_lid integer NOT NULL,
    resume_achievement_lid integer NOT NULL,
    publication_role character varying(100),
    no_of_authors character varying(100),
    publisher character varying(50),
    year_of_publication character varying(50),
    publication_url_path character varying(200),
    active boolean DEFAULT true NOT NULL,
    application_lid bigint
);
 &   DROP TABLE public.resume_publication;
       public         heap    postgres    false            ?           1259    87293 -   resume_publication_resume_publication_lid_seq    SEQUENCE     ?   CREATE SEQUENCE public.resume_publication_resume_publication_lid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 D   DROP SEQUENCE public.resume_publication_resume_publication_lid_seq;
       public          postgres    false    421            ?           0    0 -   resume_publication_resume_publication_lid_seq    SEQUENCE OWNED BY        ALTER SEQUENCE public.resume_publication_resume_publication_lid_seq OWNED BY public.resume_publication.resume_publication_lid;
          public          postgres    false    422            ?           1259    87294    resume_qualification    TABLE     ?  CREATE TABLE public.resume_qualification (
    resume_qualification_lid integer NOT NULL,
    resume_lid integer,
    qualification_type_lid integer,
    topic_of_study character varying(50),
    university character varying(100),
    institute character varying(100),
    percentile numeric(6,3),
    year_of_passing character varying(20),
    url_path character varying(200),
    active boolean DEFAULT true NOT NULL,
    is_completed boolean,
    application_lid bigint
);
 (   DROP TABLE public.resume_qualification;
       public         heap    postgres    false            ?           1259    87298 1   resume_qualification_resume_qualification_lid_seq    SEQUENCE     ?   CREATE SEQUENCE public.resume_qualification_resume_qualification_lid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 H   DROP SEQUENCE public.resume_qualification_resume_qualification_lid_seq;
       public          postgres    false    423            ?           0    0 1   resume_qualification_resume_qualification_lid_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE public.resume_qualification_resume_qualification_lid_seq OWNED BY public.resume_qualification.resume_qualification_lid;
          public          postgres    false    424            ?           1259    87299    resume_research    TABLE     h  CREATE TABLE public.resume_research (
    resume_research_lid integer NOT NULL,
    resume_achievement_lid integer NOT NULL,
    volume_year character varying(100),
    category character varying(100),
    description character varying(500),
    research_url_path character varying(200),
    active boolean DEFAULT true NOT NULL,
    application_lid bigint
);
 #   DROP TABLE public.resume_research;
       public         heap    postgres    false            ?           1259    87305 '   resume_research_resume_research_lid_seq    SEQUENCE     ?   CREATE SEQUENCE public.resume_research_resume_research_lid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 >   DROP SEQUENCE public.resume_research_resume_research_lid_seq;
       public          postgres    false    425            ?           0    0 '   resume_research_resume_research_lid_seq    SEQUENCE OWNED BY     s   ALTER SEQUENCE public.resume_research_resume_research_lid_seq OWNED BY public.resume_research.resume_research_lid;
          public          postgres    false    426            ?           1259    87306    resume_skill_selected    TABLE     ?   CREATE TABLE public.resume_skill_selected (
    resume_skill_selected_lid integer NOT NULL,
    resume_lid integer,
    skill_lid integer,
    active boolean DEFAULT true NOT NULL,
    application_lid bigint
);
 )   DROP TABLE public.resume_skill_selected;
       public         heap    postgres    false            ?           1259    87310 3   resume_skill_selected_resume_skill_selected_lid_seq    SEQUENCE     ?   CREATE SEQUENCE public.resume_skill_selected_resume_skill_selected_lid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.resume_skill_selected_resume_skill_selected_lid_seq;
       public          postgres    false    427            ?           0    0 3   resume_skill_selected_resume_skill_selected_lid_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE public.resume_skill_selected_resume_skill_selected_lid_seq OWNED BY public.resume_skill_selected.resume_skill_selected_lid;
          public          postgres    false    428            ?           1259    87311    role    TABLE     ?   CREATE TABLE public.role (
    id integer NOT NULL,
    name character varying(30) NOT NULL,
    active boolean DEFAULT true NOT NULL
);
    DROP TABLE public.role;
       public         heap    postgres    false            ?           1259    87315    role_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.role_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 "   DROP SEQUENCE public.role_id_seq;
       public          postgres    false    429            ?           0    0    role_id_seq    SEQUENCE OWNED BY     ;   ALTER SEQUENCE public.role_id_seq OWNED BY public.role.id;
          public          postgres    false    430            ?           1259    87316    session_info    TABLE     ?  CREATE TABLE public.session_info (
    session_handle character varying(255) NOT NULL,
    user_id character varying(20) NOT NULL,
    user_lid integer,
    refresh_token_hash_2 character varying(128) NOT NULL,
    session_data text,
    expires_at timestamp without time zone NOT NULL,
    created_at_time timestamp without time zone DEFAULT now() NOT NULL,
    jwt_user_payload text
);
     DROP TABLE public.session_info;
       public         heap    postgres    false            ?           1259    87322    skill    TABLE     ?   CREATE TABLE public.skill (
    id integer NOT NULL,
    skill_type_lid integer,
    skill_name character varying(255) NOT NULL,
    active boolean DEFAULT true NOT NULL
);
    DROP TABLE public.skill;
       public         heap    postgres    false            ?           1259    87326    skill_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.skill_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE public.skill_id_seq;
       public          postgres    false    432            ?           0    0    skill_id_seq    SEQUENCE OWNED BY     =   ALTER SEQUENCE public.skill_id_seq OWNED BY public.skill.id;
          public          postgres    false    433            ?           1259    87327 
   skill_type    TABLE     ?   CREATE TABLE public.skill_type (
    id integer NOT NULL,
    name character varying(30),
    description character varying(100),
    parent_lid integer,
    active boolean DEFAULT true NOT NULL
);
    DROP TABLE public.skill_type;
       public         heap    postgres    false            ?           1259    87331    skill_type_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.skill_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.skill_type_id_seq;
       public          postgres    false    434            ?           0    0    skill_type_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.skill_type_id_seq OWNED BY public.skill_type.id;
          public          postgres    false    435            ?           1259    134476    temp_achievement    TABLE     ?  CREATE TABLE public.temp_achievement (
    id integer NOT NULL,
    resume_lid integer,
    achievement_type_lid integer,
    organization_name character varying(500),
    title character varying(100) NOT NULL,
    organization_type_lid integer,
    achievement_date date,
    description character varying(100),
    url_path character varying(500),
    duration character varying(100)
);
 $   DROP TABLE public.temp_achievement;
       public         heap    postgres    false            ?           1259    134475    temp_achievement_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.temp_achievement_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.temp_achievement_id_seq;
       public          postgres    false    455            ?           0    0    temp_achievement_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.temp_achievement_id_seq OWNED BY public.temp_achievement.id;
          public          postgres    false    454            ?           1259    135124    temp_application    TABLE     ?   CREATE TABLE public.temp_application (
    id integer NOT NULL,
    resume_lid integer NOT NULL,
    organization_lid character varying NOT NULL,
    application_lid integer,
    active boolean DEFAULT true NOT NULL
);
 $   DROP TABLE public.temp_application;
       public         heap    postgres    false            ?           1259    135123    temp_application_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.temp_application_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.temp_application_id_seq;
       public          postgres    false    459            ?           0    0    temp_application_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.temp_application_id_seq OWNED BY public.temp_application.id;
          public          postgres    false    458            ?           1259    136447 	   temp_data    TABLE     ?   CREATE TABLE public.temp_data (
    id integer NOT NULL,
    organization_lid character varying,
    input_text character varying
);
    DROP TABLE public.temp_data;
       public         heap    postgres    false            ?           1259    136446    temp_data_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.temp_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.temp_data_id_seq;
       public          postgres    false    462            ?           0    0    temp_data_id_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE public.temp_data_id_seq OWNED BY public.temp_data.id;
          public          postgres    false    461            ?           1259    87349    temp_publication    TABLE     ?  CREATE TABLE public.temp_publication (
    id integer NOT NULL,
    resume_achievement_lid integer NOT NULL,
    resume_lid integer,
    achievement_type_lid integer,
    organization_name character varying(500),
    title character varying(100) NOT NULL,
    organization_type_lid integer,
    achievement_date date,
    description character varying(100),
    url_path character varying(500),
    duration character varying(100),
    publication_role character varying(100),
    no_of_authors character varying(100),
    publisher character varying(100),
    year_of_publication character varying(200),
    publication_url_path character varying(255),
    active boolean DEFAULT true NOT NULL
);
 $   DROP TABLE public.temp_publication;
       public         heap    postgres    false            ?           1259    134933    temp_publication_exp    TABLE     g  CREATE TABLE public.temp_publication_exp (
    id integer NOT NULL,
    resume_lid integer,
    achievement_type_lid integer,
    organization_name character varying(500),
    title character varying(100) NOT NULL,
    organization_type_lid integer,
    achievement_date date,
    description character varying(100),
    url_path character varying(500),
    duration character varying(100),
    publication_role character varying(100),
    no_of_authors character varying(100),
    publisher character varying(100),
    year_of_publication character varying(200),
    publication_url_path character varying(255)
);
 (   DROP TABLE public.temp_publication_exp;
       public         heap    postgres    false            ?           1259    134932    temp_publication_exp_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.temp_publication_exp_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.temp_publication_exp_id_seq;
       public          postgres    false    457            ?           0    0    temp_publication_exp_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.temp_publication_exp_id_seq OWNED BY public.temp_publication_exp.id;
          public          postgres    false    456            ?           1259    87361    temp_publication_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.temp_publication_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.temp_publication_id_seq;
       public          postgres    false    436            ?           0    0    temp_publication_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.temp_publication_id_seq OWNED BY public.temp_publication.id;
          public          postgres    false    437            ?           1259    133253    temp_research    TABLE     '  CREATE TABLE public.temp_research (
    id integer NOT NULL,
    resume_lid integer,
    achievement_type_lid integer,
    organization_name character varying(500),
    title character varying(100) NOT NULL,
    organization_type_lid integer,
    achievement_date date,
    description character varying(100),
    url_path character varying(500),
    duration character varying(100),
    volume_year character varying(100),
    category character varying(100),
    research_url_path character varying(255),
    active boolean DEFAULT true NOT NULL
);
 !   DROP TABLE public.temp_research;
       public         heap    postgres    false            ?           1259    133252    temp_research_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.temp_research_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.temp_research_id_seq;
       public          postgres    false    453            ?           0    0    temp_research_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE public.temp_research_id_seq OWNED BY public.temp_research.id;
          public          postgres    false    452            ?           1259    104523    test    TABLE     X   CREATE TABLE public.test (
    id integer NOT NULL,
    json1 jsonb,
    json2 jsonb
);
    DROP TABLE public.test;
       public         heap    postgres    false            ?           1259    104522    test_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.test_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 "   DROP SEQUENCE public.test_id_seq;
       public          postgres    false    449            ?           0    0    test_id_seq    SEQUENCE OWNED BY     ;   ALTER SEQUENCE public.test_id_seq OWNED BY public.test.id;
          public          postgres    false    448            ?           1259    87369    user    TABLE       CREATE TABLE public."user" (
    id integer NOT NULL,
    user_id character varying(20) NOT NULL,
    password_hash character varying(255),
    active boolean DEFAULT true NOT NULL,
    created_at_time timestamp without time zone DEFAULT now() NOT NULL,
    email character varying
);
    DROP TABLE public."user";
       public         heap    postgres    false            ?           1259    87376    user_address    TABLE        CREATE TABLE public.user_address (
    user_lid integer,
    address character varying(255) NOT NULL,
    address_type_lid integer,
    active boolean DEFAULT true NOT NULL,
    city character varying(100) NOT NULL,
    pin_code character varying(100) NOT NULL,
    resume_lid integer
);
     DROP TABLE public.user_address;
       public         heap    postgres    false            ?           1259    87380    user_application    TABLE     ?  CREATE TABLE public.user_application (
    appln_id integer NOT NULL,
    resume_lid integer NOT NULL,
    organization_lid character varying(100) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_by character varying(255),
    created_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_modified_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_modified_by character varying(255)
);
 $   DROP TABLE public.user_application;
       public         heap    postgres    false            ?           1259    87388    user_application_appln_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.user_application_appln_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.user_application_appln_id_seq;
       public          postgres    false    440            ?           0    0    user_application_appln_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public.user_application_appln_id_seq OWNED BY public.user_application.appln_id;
          public          postgres    false    441            ?           1259    87389    user_contact    TABLE     ?   CREATE TABLE public.user_contact (
    user_lid integer,
    contact_number character varying(10) NOT NULL,
    temp_contact_number character varying(10),
    active boolean DEFAULT true NOT NULL,
    resume_lid integer
);
     DROP TABLE public.user_contact;
       public         heap    postgres    false            ?           1259    87393    user_gender    TABLE     ?   CREATE TABLE public.user_gender (
    id integer NOT NULL,
    name character varying(10) NOT NULL,
    active boolean DEFAULT true NOT NULL
);
    DROP TABLE public.user_gender;
       public         heap    postgres    false            ?           1259    87397    user_gender_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.user_gender_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.user_gender_id_seq;
       public          postgres    false    443            ?           0    0    user_gender_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.user_gender_id_seq OWNED BY public.user_gender.id;
          public          postgres    false    444            ?           1259    87398    user_id_seq    SEQUENCE     ?   CREATE SEQUENCE public.user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 "   DROP SEQUENCE public.user_id_seq;
       public          postgres    false    438            ?           0    0    user_id_seq    SEQUENCE OWNED BY     =   ALTER SEQUENCE public.user_id_seq OWNED BY public."user".id;
          public          postgres    false    445            ?           1259    87399 	   user_info    TABLE     ?  CREATE TABLE public.user_info (
    user_lid integer,
    email character varying(150) NOT NULL,
    f_name character varying(40) NOT NULL,
    l_name character varying(50) NOT NULL,
    date_of_birth date NOT NULL,
    pancard_no character varying(15) NOT NULL,
    aadhar_card_no character varying(15),
    temp_email character varying(150),
    gender_lid integer,
    pancard_url_path character varying(150) NOT NULL,
    profile_url_path character varying(250) NOT NULL,
    aadhar_card_url_path character varying(150),
    nationality character varying(30) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    resume_lid integer
);
    DROP TABLE public.user_info;
       public         heap    postgres    false            ?           1259    87405 	   user_role    TABLE     `   CREATE TABLE public.user_role (
    user_lid integer NOT NULL,
    role_lid integer NOT NULL
);
    DROP TABLE public.user_role;
       public         heap    postgres    false            ?           2604    87408    achievement_type id    DEFAULT     z   ALTER TABLE ONLY public.achievement_type ALTER COLUMN id SET DEFAULT nextval('public.achievement_type_id_seq'::regclass);
 B   ALTER TABLE public.achievement_type ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    353    352            ?           2604    87409    address_type id    DEFAULT     r   ALTER TABLE ONLY public.address_type ALTER COLUMN id SET DEFAULT nextval('public.address_type_id_seq'::regclass);
 >   ALTER TABLE public.address_type ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    355    354            ?           2604    87410    admin_organization id    DEFAULT     ~   ALTER TABLE ONLY public.admin_organization ALTER COLUMN id SET DEFAULT nextval('public.admin_organization_id_seq'::regclass);
 D   ALTER TABLE public.admin_organization ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    357    356            ?           2604    87411 
   app_url id    DEFAULT     h   ALTER TABLE ONLY public.app_url ALTER COLUMN id SET DEFAULT nextval('public.app_url_id_seq'::regclass);
 9   ALTER TABLE public.app_url ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    359    358            ?           2604    87412 #   application_bank_details rev_number    DEFAULT     ?   ALTER TABLE ONLY public.application_bank_details ALTER COLUMN rev_number SET DEFAULT nextval('public.application_bank_details_rev_number_seq'::regclass);
 R   ALTER TABLE public.application_bank_details ALTER COLUMN rev_number DROP DEFAULT;
       public          postgres    false    361    360            ?           2604    87413 )   application_resume_achievement rev_number    DEFAULT     ?   ALTER TABLE ONLY public.application_resume_achievement ALTER COLUMN rev_number SET DEFAULT nextval('public.application_resume_achievement_rev_number_seq'::regclass);
 X   ALTER TABLE public.application_resume_achievement ALTER COLUMN rev_number DROP DEFAULT;
       public          postgres    false    363    362            ?           2604    87414 (   application_resume_experience rev_number    DEFAULT     ?   ALTER TABLE ONLY public.application_resume_experience ALTER COLUMN rev_number SET DEFAULT nextval('public.application_resume_experience_rev_number_seq'::regclass);
 W   ALTER TABLE public.application_resume_experience ALTER COLUMN rev_number DROP DEFAULT;
       public          postgres    false    365    364            ?           2604    87415 )   application_resume_publication rev_number    DEFAULT     ?   ALTER TABLE ONLY public.application_resume_publication ALTER COLUMN rev_number SET DEFAULT nextval('public.application_resume_publication_rev_number_seq'::regclass);
 X   ALTER TABLE public.application_resume_publication ALTER COLUMN rev_number DROP DEFAULT;
       public          postgres    false    367    366            ?           2604    87416 #   application_resume_qualification id    DEFAULT     ?   ALTER TABLE ONLY public.application_resume_qualification ALTER COLUMN id SET DEFAULT nextval('public.application_resume_qualification_rev_number_seq'::regclass);
 R   ALTER TABLE public.application_resume_qualification ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    369    368            ?           2604    87417 &   application_resume_research rev_number    DEFAULT     ?   ALTER TABLE ONLY public.application_resume_research ALTER COLUMN rev_number SET DEFAULT nextval('public.application_resume_research_rev_number_seq'::regclass);
 U   ALTER TABLE public.application_resume_research ALTER COLUMN rev_number DROP DEFAULT;
       public          postgres    false    371    370            ?           2604    87418 ,   application_resume_skill_selected rev_number    DEFAULT     ?   ALTER TABLE ONLY public.application_resume_skill_selected ALTER COLUMN rev_number SET DEFAULT nextval('public.application_resume_skill_selected_rev_number_seq'::regclass);
 [   ALTER TABLE public.application_resume_skill_selected ALTER COLUMN rev_number DROP DEFAULT;
       public          postgres    false    373    372            ?           2604    87419    application_status id    DEFAULT     ~   ALTER TABLE ONLY public.application_status ALTER COLUMN id SET DEFAULT nextval('public.application_status_id_seq'::regclass);
 D   ALTER TABLE public.application_status ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    375    374            ?           2604    87420 #   application_user_address rev_number    DEFAULT     ?   ALTER TABLE ONLY public.application_user_address ALTER COLUMN rev_number SET DEFAULT nextval('public.application_user_address_rev_number_seq'::regclass);
 R   ALTER TABLE public.application_user_address ALTER COLUMN rev_number DROP DEFAULT;
       public          postgres    false    377    376            ?           2604    87421 #   application_user_contact rev_number    DEFAULT     ?   ALTER TABLE ONLY public.application_user_contact ALTER COLUMN rev_number SET DEFAULT nextval('public.application_user_contact_rev_number_seq'::regclass);
 R   ALTER TABLE public.application_user_contact ALTER COLUMN rev_number DROP DEFAULT;
       public          postgres    false    379    378            ?           2604    87422     application_user_info rev_number    DEFAULT     ?   ALTER TABLE ONLY public.application_user_info ALTER COLUMN rev_number SET DEFAULT nextval('public.application_user_info_rev_number_seq'::regclass);
 O   ALTER TABLE public.application_user_info ALTER COLUMN rev_number DROP DEFAULT;
       public          postgres    false    381    380            ?           2604    87423    approved_faculty_status id    DEFAULT     ?   ALTER TABLE ONLY public.approved_faculty_status ALTER COLUMN id SET DEFAULT nextval('public.approved_faculty_status_id_seq'::regclass);
 I   ALTER TABLE public.approved_faculty_status ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    383    382            ?           2604    87424    bank_account_type id    DEFAULT     |   ALTER TABLE ONLY public.bank_account_type ALTER COLUMN id SET DEFAULT nextval('public.bank_account_type_id_seq'::regclass);
 C   ALTER TABLE public.bank_account_type ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    385    384            ?           2604    87425 	   campus id    DEFAULT     f   ALTER TABLE ONLY public.campus ALTER COLUMN id SET DEFAULT nextval('public.campus_id_seq'::regclass);
 8   ALTER TABLE public.campus ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    388    387            ?           2604    87426    designation id    DEFAULT     p   ALTER TABLE ONLY public.designation ALTER COLUMN id SET DEFAULT nextval('public.designation_id_seq'::regclass);
 =   ALTER TABLE public.designation ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    390    389            ?           2604    87427    discontinue_details id    DEFAULT     ?   ALTER TABLE ONLY public.discontinue_details ALTER COLUMN id SET DEFAULT nextval('public.discontinue_details_id_seq'::regclass);
 E   ALTER TABLE public.discontinue_details ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    392    391            ?           2604    87428    experience_type id    DEFAULT     x   ALTER TABLE ONLY public.experience_type ALTER COLUMN id SET DEFAULT nextval('public.experience_type_id_seq'::regclass);
 A   ALTER TABLE public.experience_type ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    394    393            ?           2604    87429    http_method id    DEFAULT     p   ALTER TABLE ONLY public.http_method ALTER COLUMN id SET DEFAULT nextval('public.http_method_id_seq'::regclass);
 =   ALTER TABLE public.http_method ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    396    395            ?           2604    87430    level id    DEFAULT     d   ALTER TABLE ONLY public.level ALTER COLUMN id SET DEFAULT nextval('public.level_id_seq'::regclass);
 7   ALTER TABLE public.level ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    398    397            ?           2604    128298    offer_letter_details id    DEFAULT     ?   ALTER TABLE ONLY public.offer_letter_details ALTER COLUMN id SET DEFAULT nextval('public.offer_letter_details_id_seq'::regclass);
 F   ALTER TABLE public.offer_letter_details ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    451    450    451            ?           2604    87431    organization id    DEFAULT     r   ALTER TABLE ONLY public.organization ALTER COLUMN id SET DEFAULT nextval('public.organization_id_seq'::regclass);
 >   ALTER TABLE public.organization ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    402    401            ?           2604    87432    organization_type id    DEFAULT     |   ALTER TABLE ONLY public.organization_type ALTER COLUMN id SET DEFAULT nextval('public.organization_type_id_seq'::regclass);
 C   ALTER TABLE public.organization_type ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    404    403            ?           2604    87433    profile_category_settings id    DEFAULT     ?   ALTER TABLE ONLY public.profile_category_settings ALTER COLUMN id SET DEFAULT nextval('public.profile_category_settings_id_seq'::regclass);
 K   ALTER TABLE public.profile_category_settings ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    406    405            ?           2604    87434    proforma_details proforma_id    DEFAULT     ?   ALTER TABLE ONLY public.proforma_details ALTER COLUMN proforma_id SET DEFAULT nextval('public.proforma_details_proforma_id_seq'::regclass);
 K   ALTER TABLE public.proforma_details ALTER COLUMN proforma_id DROP DEFAULT;
       public          postgres    false    408    407            ?           2604    87435    proforma_status id    DEFAULT     x   ALTER TABLE ONLY public.proforma_status ALTER COLUMN id SET DEFAULT nextval('public.proforma_status_id_seq'::regclass);
 A   ALTER TABLE public.proforma_status ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    410    409            ?           2604    87436    qualification_type id    DEFAULT     ~   ALTER TABLE ONLY public.qualification_type ALTER COLUMN id SET DEFAULT nextval('public.qualification_type_id_seq'::regclass);
 D   ALTER TABLE public.qualification_type ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    412    411            ?           2604    87437 	   resume id    DEFAULT     f   ALTER TABLE ONLY public.resume ALTER COLUMN id SET DEFAULT nextval('public.resume_id_seq'::regclass);
 8   ALTER TABLE public.resume ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    418    413            ?           2604    87438 )   resume_achievement resume_achievement_lid    DEFAULT     ?   ALTER TABLE ONLY public.resume_achievement ALTER COLUMN resume_achievement_lid SET DEFAULT nextval('public.resume_achievement_resume_achievement_lid_seq'::regclass);
 X   ALTER TABLE public.resume_achievement ALTER COLUMN resume_achievement_lid DROP DEFAULT;
       public          postgres    false    415    414            ?           2604    87439 '   resume_experience resume_experience_lid    DEFAULT     ?   ALTER TABLE ONLY public.resume_experience ALTER COLUMN resume_experience_lid SET DEFAULT nextval('public.resume_experience_resume_experience_lid_seq'::regclass);
 V   ALTER TABLE public.resume_experience ALTER COLUMN resume_experience_lid DROP DEFAULT;
       public          postgres    false    417    416            ?           2604    87440    resume_profile_category id    DEFAULT     ?   ALTER TABLE ONLY public.resume_profile_category ALTER COLUMN id SET DEFAULT nextval('public.resume_profile_category_id_seq'::regclass);
 I   ALTER TABLE public.resume_profile_category ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    420    419            ?           2604    87441 )   resume_publication resume_publication_lid    DEFAULT     ?   ALTER TABLE ONLY public.resume_publication ALTER COLUMN resume_publication_lid SET DEFAULT nextval('public.resume_publication_resume_publication_lid_seq'::regclass);
 X   ALTER TABLE public.resume_publication ALTER COLUMN resume_publication_lid DROP DEFAULT;
       public          postgres    false    422    421            ?           2604    87442 -   resume_qualification resume_qualification_lid    DEFAULT     ?   ALTER TABLE ONLY public.resume_qualification ALTER COLUMN resume_qualification_lid SET DEFAULT nextval('public.resume_qualification_resume_qualification_lid_seq'::regclass);
 \   ALTER TABLE public.resume_qualification ALTER COLUMN resume_qualification_lid DROP DEFAULT;
       public          postgres    false    424    423            ?           2604    87443 #   resume_research resume_research_lid    DEFAULT     ?   ALTER TABLE ONLY public.resume_research ALTER COLUMN resume_research_lid SET DEFAULT nextval('public.resume_research_resume_research_lid_seq'::regclass);
 R   ALTER TABLE public.resume_research ALTER COLUMN resume_research_lid DROP DEFAULT;
       public          postgres    false    426    425            ?           2604    87444 /   resume_skill_selected resume_skill_selected_lid    DEFAULT     ?   ALTER TABLE ONLY public.resume_skill_selected ALTER COLUMN resume_skill_selected_lid SET DEFAULT nextval('public.resume_skill_selected_resume_skill_selected_lid_seq'::regclass);
 ^   ALTER TABLE public.resume_skill_selected ALTER COLUMN resume_skill_selected_lid DROP DEFAULT;
       public          postgres    false    428    427            ?           2604    87445    role id    DEFAULT     b   ALTER TABLE ONLY public.role ALTER COLUMN id SET DEFAULT nextval('public.role_id_seq'::regclass);
 6   ALTER TABLE public.role ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    430    429            ?           2604    87446    skill id    DEFAULT     d   ALTER TABLE ONLY public.skill ALTER COLUMN id SET DEFAULT nextval('public.skill_id_seq'::regclass);
 7   ALTER TABLE public.skill ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    433    432            ?           2604    87447    skill_type id    DEFAULT     n   ALTER TABLE ONLY public.skill_type ALTER COLUMN id SET DEFAULT nextval('public.skill_type_id_seq'::regclass);
 <   ALTER TABLE public.skill_type ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    435    434            ?           2604    134479    temp_achievement id    DEFAULT     z   ALTER TABLE ONLY public.temp_achievement ALTER COLUMN id SET DEFAULT nextval('public.temp_achievement_id_seq'::regclass);
 B   ALTER TABLE public.temp_achievement ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    455    454    455            ?           2604    135127    temp_application id    DEFAULT     z   ALTER TABLE ONLY public.temp_application ALTER COLUMN id SET DEFAULT nextval('public.temp_application_id_seq'::regclass);
 B   ALTER TABLE public.temp_application ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    459    458    459                       2604    136450    temp_data id    DEFAULT     l   ALTER TABLE ONLY public.temp_data ALTER COLUMN id SET DEFAULT nextval('public.temp_data_id_seq'::regclass);
 ;   ALTER TABLE public.temp_data ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    461    462    462            ?           2604    87451    temp_publication id    DEFAULT     z   ALTER TABLE ONLY public.temp_publication ALTER COLUMN id SET DEFAULT nextval('public.temp_publication_id_seq'::regclass);
 B   ALTER TABLE public.temp_publication ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    437    436            ?           2604    134936    temp_publication_exp id    DEFAULT     ?   ALTER TABLE ONLY public.temp_publication_exp ALTER COLUMN id SET DEFAULT nextval('public.temp_publication_exp_id_seq'::regclass);
 F   ALTER TABLE public.temp_publication_exp ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    456    457    457            ?           2604    133256    temp_research id    DEFAULT     t   ALTER TABLE ONLY public.temp_research ALTER COLUMN id SET DEFAULT nextval('public.temp_research_id_seq'::regclass);
 ?   ALTER TABLE public.temp_research ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    453    452    453            ?           2604    104526    test id    DEFAULT     b   ALTER TABLE ONLY public.test ALTER COLUMN id SET DEFAULT nextval('public.test_id_seq'::regclass);
 6   ALTER TABLE public.test ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    448    449    449            ?           2604    87454    user id    DEFAULT     d   ALTER TABLE ONLY public."user" ALTER COLUMN id SET DEFAULT nextval('public.user_id_seq'::regclass);
 8   ALTER TABLE public."user" ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    445    438            ?           2604    87455    user_application appln_id    DEFAULT     ?   ALTER TABLE ONLY public.user_application ALTER COLUMN appln_id SET DEFAULT nextval('public.user_application_appln_id_seq'::regclass);
 H   ALTER TABLE public.user_application ALTER COLUMN appln_id DROP DEFAULT;
       public          postgres    false    441    440            ?           2604    87456    user_gender id    DEFAULT     p   ALTER TABLE ONLY public.user_gender ALTER COLUMN id SET DEFAULT nextval('public.user_gender_id_seq'::regclass);
 =   ALTER TABLE public.user_gender ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    444    443            !          0    87064    achievement_type 
   TABLE DATA           [   COPY public.achievement_type (id, name, description, parent_lid, active, abbr) FROM stdin;
    public          postgres    false    352   J?      #          0    87069    address_type 
   TABLE DATA           8   COPY public.address_type (id, name, active) FROM stdin;
    public          postgres    false    354   ??      %          0    87074    admin_organization 
   TABLE DATA           T   COPY public.admin_organization (id, user_lid, organization_lid, active) FROM stdin;
    public          postgres    false    356   ??      '          0    87081    app_url 
   TABLE DATA           O   COPY public.app_url (id, name, tag, path_name, parent_lid, active) FROM stdin;
    public          postgres    false    358   )?      )          0    87086    application_bank_details 
   TABLE DATA           ?   COPY public.application_bank_details (rev_number, rev_timestamp, user_lid, bank_account_type_lid, resume_lid, bank_name, branch_name, ifsc_code, micr_code, account_number, url_path, active, application_lid) FROM stdin;
    public          postgres    false    360   F?      +          0    87094    application_resume_achievement 
   TABLE DATA           
  COPY public.application_resume_achievement (rev_number, rev_timestamp, resume_achievement_lid, resume_lid, achievement_type_lid, title, description, organization_name, organization_type_lid, url_path, achievement_date, duration, active, application_lid) FROM stdin;
    public          postgres    false    362   c?      -          0    87102    application_resume_experience 
   TABLE DATA           %  COPY public.application_resume_experience (rev_number, rev_timestamp, resume_experience_lid, resume_lid, experience_type_lid, employer_name, designation, designation_lid, description, start_date, end_date, responsibilities, is_current, active, duration, padagogy, application_lid) FROM stdin;
    public          postgres    false    364   ??      /          0    87111    application_resume_publication 
   TABLE DATA           ?   COPY public.application_resume_publication (rev_number, rev_timestamp, resume_publication_lid, resume_achievement_lid, publication_role, no_of_authors, publisher, year_of_publication, publication_url_path, active, application_lid) FROM stdin;
    public          postgres    false    366   ??      1          0    87119     application_resume_qualification 
   TABLE DATA              COPY public.application_resume_qualification (id, rev_timestamp, resume_qualification_lid, resume_lid, qualification_type_lid, topic_of_study, university, institute, percentile, year_of_passing, url_path, active, is_completed, application_lid) FROM stdin;
    public          postgres    false    368   ??      3          0    87125    application_resume_research 
   TABLE DATA           ?   COPY public.application_resume_research (rev_number, rev_timestamp, resume_research_lid, resume_achievement_lid, volume_year, description, category, research_url_path, active, application_lid) FROM stdin;
    public          postgres    false    370   ??      5          0    87133 !   application_resume_skill_selected 
   TABLE DATA           ?   COPY public.application_resume_skill_selected (rev_number, rev_timestamp, resume_skill_selected_lid, resume_lid, skill_lid, active, application_lid) FROM stdin;
    public          postgres    false    372   ??      7          0    87139    application_status 
   TABLE DATA           >   COPY public.application_status (id, name, active) FROM stdin;
    public          postgres    false    374   ?      9          0    87144    application_user_address 
   TABLE DATA           ?   COPY public.application_user_address (rev_number, rev_timestamp, user_lid, address, address_type_lid, city, pin_code, active, resume_lid, application_lid) FROM stdin;
    public          postgres    false    376   g?      ;          0    87152    application_user_contact 
   TABLE DATA           ?   COPY public.application_user_contact (rev_number, rev_timestamp, user_lid, contact_number, temp_contact_number, active, resume_lid, application_lid) FROM stdin;
    public          postgres    false    378   ??      =          0    87158    application_user_info 
   TABLE DATA             COPY public.application_user_info (rev_number, rev_timestamp, user_lid, email, f_name, l_name, date_of_birth, pancard_no, aadhar_card_no, temp_email, gender_lid, pancard_url_path, profile_url_path, aadhar_card_url_path, nationality, active, resume_lid, application_lid) FROM stdin;
    public          postgres    false    380   ??      ?          0    87166    approved_faculty_status 
   TABLE DATA           n   COPY public.approved_faculty_status (id, proforma_lid, created_by, created_date, is_discontinued) FROM stdin;
    public          postgres    false    382   ??      A          0    87172    bank_account_type 
   TABLE DATA           K   COPY public.bank_account_type (id, account_type, active, abbr) FROM stdin;
    public          postgres    false    384   ??      C          0    87177    bank_details 
   TABLE DATA           ?   COPY public.bank_details (user_lid, bank_account_type_lid, resume_lid, bank_name, branch_name, ifsc_code, micr_code, account_number, url_path, active) FROM stdin;
    public          postgres    false    386   a?      D          0    87183    campus 
   TABLE DATA           P   COPY public.campus (id, campus_id, abbr, name, description, active) FROM stdin;
    public          postgres    false    387   ~?      F          0    87188    designation 
   TABLE DATA           ?   COPY public.designation (id, name, points, active) FROM stdin;
    public          postgres    false    389   ??      H          0    87193    discontinue_details 
   TABLE DATA           ?   COPY public.discontinue_details (id, proforma_lid, organization_lid, comment, created_by, created_date, active, is_discontinued) FROM stdin;
    public          postgres    false    391   ??      J          0    87200    experience_type 
   TABLE DATA           b   COPY public.experience_type (id, name, description, parent_lid, active, points, abbr) FROM stdin;
    public          postgres    false    393   ??      L          0    87205    http_method 
   TABLE DATA           D   COPY public.http_method (id, name, method_name, active) FROM stdin;
    public          postgres    false    395   5?      N          0    87210    level 
   TABLE DATA           4   COPY public.level (id, role_lid, level) FROM stdin;
    public          postgres    false    397   ??      P          0    87214    modules 
   TABLE DATA           w   COPY public.modules (id, module_id, name, program_name, program_id, acad_session, tmp_proforma_id, active) FROM stdin;
    public          postgres    false    399   ??      ?          0    128295    offer_letter_details 
   TABLE DATA           t   COPY public.offer_letter_details (id, proforma_id, status, reason, created_on, created_by, approved_by) FROM stdin;
    public          postgres    false    451   ??      R          0    87221    organization 
   TABLE DATA           h   COPY public.organization (id, organization_id, abbr, name, description, campus_lid, active) FROM stdin;
    public          postgres    false    401   ??      T          0    87228    organization_type 
   TABLE DATA           P   COPY public.organization_type (id, name, description, active, abbr) FROM stdin;
    public          postgres    false    403   ??      V          0    87233    profile_category_settings 
   TABLE DATA           y   COPY public.profile_category_settings (id, profile_category_id, range_start, range_end, range_point, active) FROM stdin;
    public          postgres    false    405   ?      X          0    87238    proforma_details 
   TABLE DATA           {  COPY public.proforma_details (proforma_id, application_lid, module, teaching_hours, program_id, acad_session, commencement_date_of_program, rate_per_hours, total_no_of_hrs_alloted, no_of_division, student_count_per_division, aol_obe, created_by, created_date, level, status_lid, tag_id, last_modified_date, active, program_name, module_id, vf_module_id, modified_by) FROM stdin;
    public          postgres    false    407   {?      Z          0    87248    proforma_status 
   TABLE DATA           ?   COPY public.proforma_status (id, proforma_lid, approved_by, level, status_lid, comment, created_date, file_path, tag_id, active) FROM stdin;
    public          postgres    false    409   ??      \          0    87256    qualification_type 
   TABLE DATA           ]   COPY public.qualification_type (id, name, description, parent_lid, active, abbr) FROM stdin;
    public          postgres    false    411   ??      ^          0    87261    resume 
   TABLE DATA           u   COPY public.resume (id, user_lid, name, description, created_by, active, last_modified_by, created_date) FROM stdin;
    public          postgres    false    413   )?      _          0    87266    resume_achievement 
   TABLE DATA           ?   COPY public.resume_achievement (resume_achievement_lid, resume_lid, achievement_type_lid, title, description, organization_name, organization_type_lid, url_path, achievement_date, duration, active, application_lid) FROM stdin;
    public          postgres    false    414   F?      a          0    87273    resume_experience 
   TABLE DATA           ?   COPY public.resume_experience (resume_experience_lid, resume_lid, experience_type_lid, employer_name, designation, designation_lid, description, start_date, end_date, responsibilities, is_current, active, duration, padagogy, application_lid) FROM stdin;
    public          postgres    false    416   c?      d          0    87282    resume_profile_category 
   TABLE DATA           ?   COPY public.resume_profile_category (id, name, description, max_points, parent_lid, table_name, foreign_lid, active, json_tag, tag_name, max_limit) FROM stdin;
    public          postgres    false    419   ??      f          0    87287    resume_publication 
   TABLE DATA           ?   COPY public.resume_publication (resume_publication_lid, resume_achievement_lid, publication_role, no_of_authors, publisher, year_of_publication, publication_url_path, active, application_lid) FROM stdin;
    public          postgres    false    421   p?      h          0    87294    resume_qualification 
   TABLE DATA           ?   COPY public.resume_qualification (resume_qualification_lid, resume_lid, qualification_type_lid, topic_of_study, university, institute, percentile, year_of_passing, url_path, active, is_completed, application_lid) FROM stdin;
    public          postgres    false    423   ??      j          0    87299    resume_research 
   TABLE DATA           ?   COPY public.resume_research (resume_research_lid, resume_achievement_lid, volume_year, category, description, research_url_path, active, application_lid) FROM stdin;
    public          postgres    false    425   ??      l          0    87306    resume_skill_selected 
   TABLE DATA           z   COPY public.resume_skill_selected (resume_skill_selected_lid, resume_lid, skill_lid, active, application_lid) FROM stdin;
    public          postgres    false    427   ??      n          0    87311    role 
   TABLE DATA           0   COPY public.role (id, name, active) FROM stdin;
    public          postgres    false    429   ??      p          0    87316    session_info 
   TABLE DATA           ?   COPY public.session_info (session_handle, user_id, user_lid, refresh_token_hash_2, session_data, expires_at, created_at_time, jwt_user_payload) FROM stdin;
    public          postgres    false    431   X?      q          0    87322    skill 
   TABLE DATA           G   COPY public.skill (id, skill_type_lid, skill_name, active) FROM stdin;
    public          postgres    false    432   u?      s          0    87327 
   skill_type 
   TABLE DATA           O   COPY public.skill_type (id, name, description, parent_lid, active) FROM stdin;
    public          postgres    false    434   ??      ?          0    134476    temp_achievement 
   TABLE DATA           ?   COPY public.temp_achievement (id, resume_lid, achievement_type_lid, organization_name, title, organization_type_lid, achievement_date, description, url_path, duration) FROM stdin;
    public          postgres    false    455   ??      ?          0    135124    temp_application 
   TABLE DATA           e   COPY public.temp_application (id, resume_lid, organization_lid, application_lid, active) FROM stdin;
    public          postgres    false    459   ??      ?          0    136447 	   temp_data 
   TABLE DATA           E   COPY public.temp_data (id, organization_lid, input_text) FROM stdin;
    public          postgres    false    462   ??      u          0    87349    temp_publication 
   TABLE DATA           +  COPY public.temp_publication (id, resume_achievement_lid, resume_lid, achievement_type_lid, organization_name, title, organization_type_lid, achievement_date, description, url_path, duration, publication_role, no_of_authors, publisher, year_of_publication, publication_url_path, active) FROM stdin;
    public          postgres    false    436   ??      ?          0    134933    temp_publication_exp 
   TABLE DATA             COPY public.temp_publication_exp (id, resume_lid, achievement_type_lid, organization_name, title, organization_type_lid, achievement_date, description, url_path, duration, publication_role, no_of_authors, publisher, year_of_publication, publication_url_path) FROM stdin;
    public          postgres    false    457   S?      ?          0    133253    temp_research 
   TABLE DATA           ?   COPY public.temp_research (id, resume_lid, achievement_type_lid, organization_name, title, organization_type_lid, achievement_date, description, url_path, duration, volume_year, category, research_url_path, active) FROM stdin;
    public          postgres    false    453   ??      ?          0    104523    test 
   TABLE DATA           0   COPY public.test (id, json1, json2) FROM stdin;
    public          postgres    false    449   ?      w          0    87369    user 
   TABLE DATA           \   COPY public."user" (id, user_id, password_hash, active, created_at_time, email) FROM stdin;
    public          postgres    false    438   m?      x          0    87376    user_address 
   TABLE DATA           o   COPY public.user_address (user_lid, address, address_type_lid, active, city, pin_code, resume_lid) FROM stdin;
    public          postgres    false    439   c?      y          0    87380    user_application 
   TABLE DATA           ?   COPY public.user_application (appln_id, resume_lid, organization_lid, active, created_by, created_date, last_modified_date, last_modified_by) FROM stdin;
    public          postgres    false    440   ??      {          0    87389    user_contact 
   TABLE DATA           i   COPY public.user_contact (user_lid, contact_number, temp_contact_number, active, resume_lid) FROM stdin;
    public          postgres    false    442   ??      |          0    87393    user_gender 
   TABLE DATA           7   COPY public.user_gender (id, name, active) FROM stdin;
    public          postgres    false    443   ??                0    87399 	   user_info 
   TABLE DATA           ?   COPY public.user_info (user_lid, email, f_name, l_name, date_of_birth, pancard_no, aadhar_card_no, temp_email, gender_lid, pancard_url_path, profile_url_path, aadhar_card_url_path, nationality, active, resume_lid) FROM stdin;
    public          postgres    false    446   ??      ?          0    87405 	   user_role 
   TABLE DATA           7   COPY public.user_role (user_lid, role_lid) FROM stdin;
    public          postgres    false    447   ?      ?           0    0    achievement_type_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.achievement_type_id_seq', 3, true);
          public          postgres    false    353            ?           0    0    address_type_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.address_type_id_seq', 2, true);
          public          postgres    false    355            ?           0    0    admin_organization_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.admin_organization_id_seq', 6, true);
          public          postgres    false    357            ?           0    0    app_url_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.app_url_id_seq', 1, false);
          public          postgres    false    359            ?           0    0 '   application_bank_details_rev_number_seq    SEQUENCE SET     V   SELECT pg_catalog.setval('public.application_bank_details_rev_number_seq', 94, true);
          public          postgres    false    361            ?           0    0 -   application_resume_achievement_rev_number_seq    SEQUENCE SET     ]   SELECT pg_catalog.setval('public.application_resume_achievement_rev_number_seq', 270, true);
          public          postgres    false    363            ?           0    0 ,   application_resume_experience_rev_number_seq    SEQUENCE SET     \   SELECT pg_catalog.setval('public.application_resume_experience_rev_number_seq', 174, true);
          public          postgres    false    365            ?           0    0 -   application_resume_publication_rev_number_seq    SEQUENCE SET     \   SELECT pg_catalog.setval('public.application_resume_publication_rev_number_seq', 88, true);
          public          postgres    false    367            ?           0    0 /   application_resume_qualification_rev_number_seq    SEQUENCE SET     _   SELECT pg_catalog.setval('public.application_resume_qualification_rev_number_seq', 276, true);
          public          postgres    false    369            ?           0    0 *   application_resume_research_rev_number_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.application_resume_research_rev_number_seq', 86, true);
          public          postgres    false    371            ?           0    0 0   application_resume_skill_selected_rev_number_seq    SEQUENCE SET     `   SELECT pg_catalog.setval('public.application_resume_skill_selected_rev_number_seq', 687, true);
          public          postgres    false    373            ?           0    0    application_status_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.application_status_id_seq', 4, true);
          public          postgres    false    375            ?           0    0 '   application_user_address_rev_number_seq    SEQUENCE SET     W   SELECT pg_catalog.setval('public.application_user_address_rev_number_seq', 194, true);
          public          postgres    false    377            ?           0    0 '   application_user_contact_rev_number_seq    SEQUENCE SET     V   SELECT pg_catalog.setval('public.application_user_contact_rev_number_seq', 97, true);
          public          postgres    false    379            ?           0    0 $   application_user_info_rev_number_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public.application_user_info_rev_number_seq', 97, true);
          public          postgres    false    381            ?           0    0    approved_faculty_status_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.approved_faculty_status_id_seq', 8, true);
          public          postgres    false    383            ?           0    0    bank_account_type_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.bank_account_type_id_seq', 5, true);
          public          postgres    false    385            ?           0    0    campus_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('public.campus_id_seq', 2, true);
          public          postgres    false    388            ?           0    0    designation_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.designation_id_seq', 13, true);
          public          postgres    false    390            ?           0    0    discontinue_details_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.discontinue_details_id_seq', 42, true);
          public          postgres    false    392            ?           0    0    experience_type_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.experience_type_id_seq', 5, true);
          public          postgres    false    394            ?           0    0    http_method_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.http_method_id_seq', 5, true);
          public          postgres    false    396            ?           0    0    level_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('public.level_id_seq', 81, true);
          public          postgres    false    398            ?           0    0    modules_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.modules_id_seq', 81, true);
          public          postgres    false    400            ?           0    0    offer_letter_details_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.offer_letter_details_id_seq', 11, true);
          public          postgres    false    450            ?           0    0    organization_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.organization_id_seq', 315, true);
          public          postgres    false    402            ?           0    0    organization_type_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.organization_type_id_seq', 3, true);
          public          postgres    false    404            ?           0    0     profile_category_settings_id_seq    SEQUENCE SET     N   SELECT pg_catalog.setval('public.profile_category_settings_id_seq', 6, true);
          public          postgres    false    406            ?           0    0     proforma_details_proforma_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.proforma_details_proforma_id_seq', 98, true);
          public          postgres    false    408            ?           0    0    proforma_status_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.proforma_status_id_seq', 223, true);
          public          postgres    false    410            ?           0    0    qualification_type_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.qualification_type_id_seq', 4, true);
          public          postgres    false    412            ?           0    0 -   resume_achievement_resume_achievement_lid_seq    SEQUENCE SET     ]   SELECT pg_catalog.setval('public.resume_achievement_resume_achievement_lid_seq', 339, true);
          public          postgres    false    415            ?           0    0 +   resume_experience_resume_experience_lid_seq    SEQUENCE SET     Z   SELECT pg_catalog.setval('public.resume_experience_resume_experience_lid_seq', 94, true);
          public          postgres    false    417            ?           0    0    resume_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.resume_id_seq', 138, true);
          public          postgres    false    418            ?           0    0    resume_profile_category_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.resume_profile_category_id_seq', 20, true);
          public          postgres    false    420            ?           0    0 -   resume_publication_resume_publication_lid_seq    SEQUENCE SET     \   SELECT pg_catalog.setval('public.resume_publication_resume_publication_lid_seq', 77, true);
          public          postgres    false    422            ?           0    0 1   resume_qualification_resume_qualification_lid_seq    SEQUENCE SET     a   SELECT pg_catalog.setval('public.resume_qualification_resume_qualification_lid_seq', 234, true);
          public          postgres    false    424            ?           0    0 '   resume_research_resume_research_lid_seq    SEQUENCE SET     V   SELECT pg_catalog.setval('public.resume_research_resume_research_lid_seq', 33, true);
          public          postgres    false    426            ?           0    0 3   resume_skill_selected_resume_skill_selected_lid_seq    SEQUENCE SET     c   SELECT pg_catalog.setval('public.resume_skill_selected_resume_skill_selected_lid_seq', 787, true);
          public          postgres    false    428            ?           0    0    role_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('public.role_id_seq', 11, true);
          public          postgres    false    430            ?           0    0    skill_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('public.skill_id_seq', 201, true);
          public          postgres    false    433            ?           0    0    skill_type_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.skill_type_id_seq', 2, true);
          public          postgres    false    435            ?           0    0    temp_achievement_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.temp_achievement_id_seq', 1, true);
          public          postgres    false    454            ?           0    0    temp_application_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.temp_application_id_seq', 1, true);
          public          postgres    false    458            ?           0    0    temp_data_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('public.temp_data_id_seq', 1, true);
          public          postgres    false    461            ?           0    0    temp_publication_exp_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.temp_publication_exp_id_seq', 1, true);
          public          postgres    false    456            ?           0    0    temp_publication_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.temp_publication_id_seq', 1, true);
          public          postgres    false    437            ?           0    0    temp_research_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.temp_research_id_seq', 1, true);
          public          postgres    false    452            ?           0    0    test_id_seq    SEQUENCE SET     9   SELECT pg_catalog.setval('public.test_id_seq', 2, true);
          public          postgres    false    448            ?           0    0    user_application_appln_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.user_application_appln_id_seq', 260, true);
          public          postgres    false    441            ?           0    0    user_gender_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.user_gender_id_seq', 3, true);
          public          postgres    false    444            ?           0    0    user_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('public.user_id_seq', 141, true);
          public          postgres    false    445                       2606    87458 &   achievement_type achievement_type_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.achievement_type
    ADD CONSTRAINT achievement_type_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.achievement_type DROP CONSTRAINT achievement_type_pkey;
       public            postgres    false    352                       2606    87460    address_type address_type_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.address_type
    ADD CONSTRAINT address_type_pkey PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.address_type DROP CONSTRAINT address_type_pkey;
       public            postgres    false    354                       2606    87462 *   admin_organization admin_organization_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.admin_organization
    ADD CONSTRAINT admin_organization_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.admin_organization DROP CONSTRAINT admin_organization_pkey;
       public            postgres    false    356            	           2606    87464    app_url app_url_name_key 
   CONSTRAINT     S   ALTER TABLE ONLY public.app_url
    ADD CONSTRAINT app_url_name_key UNIQUE (name);
 B   ALTER TABLE ONLY public.app_url DROP CONSTRAINT app_url_name_key;
       public            postgres    false    358                       2606    87466    app_url app_url_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.app_url
    ADD CONSTRAINT app_url_pkey PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.app_url DROP CONSTRAINT app_url_pkey;
       public            postgres    false    358                       2606    87468 *   application_status application_status_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.application_status
    ADD CONSTRAINT application_status_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.application_status DROP CONSTRAINT application_status_pkey;
       public            postgres    false    374                       2606    87470 4   approved_faculty_status approved_faculty_status_pkey 
   CONSTRAINT     r   ALTER TABLE ONLY public.approved_faculty_status
    ADD CONSTRAINT approved_faculty_status_pkey PRIMARY KEY (id);
 ^   ALTER TABLE ONLY public.approved_faculty_status DROP CONSTRAINT approved_faculty_status_pkey;
       public            postgres    false    382                       2606    87472 (   bank_account_type bank_account_type_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.bank_account_type
    ADD CONSTRAINT bank_account_type_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.bank_account_type DROP CONSTRAINT bank_account_type_pkey;
       public            postgres    false    384                       2606    87474    campus campus_pkey 
   CONSTRAINT     P   ALTER TABLE ONLY public.campus
    ADD CONSTRAINT campus_pkey PRIMARY KEY (id);
 <   ALTER TABLE ONLY public.campus DROP CONSTRAINT campus_pkey;
       public            postgres    false    387                       2606    87476    designation designation_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.designation
    ADD CONSTRAINT designation_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.designation DROP CONSTRAINT designation_pkey;
       public            postgres    false    389                       2606    87478 ,   discontinue_details discontinue_details_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.discontinue_details
    ADD CONSTRAINT discontinue_details_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.discontinue_details DROP CONSTRAINT discontinue_details_pkey;
       public            postgres    false    391                       2606    87480 $   experience_type experience_type_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.experience_type
    ADD CONSTRAINT experience_type_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.experience_type DROP CONSTRAINT experience_type_pkey;
       public            postgres    false    393                       2606    87482    http_method http_method_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.http_method
    ADD CONSTRAINT http_method_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.http_method DROP CONSTRAINT http_method_pkey;
       public            postgres    false    395                       2606    87484    level level_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.level
    ADD CONSTRAINT level_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.level DROP CONSTRAINT level_pkey;
       public            postgres    false    397                       2606    87486    modules modules_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.modules
    ADD CONSTRAINT modules_pkey PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.modules DROP CONSTRAINT modules_pkey;
       public            postgres    false    399            [           2606    128303 .   offer_letter_details offer_letter_details_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.offer_letter_details
    ADD CONSTRAINT offer_letter_details_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.offer_letter_details DROP CONSTRAINT offer_letter_details_pkey;
       public            postgres    false    451            ]           2606    128305 9   offer_letter_details offer_letter_details_proforma_id_key 
   CONSTRAINT     {   ALTER TABLE ONLY public.offer_letter_details
    ADD CONSTRAINT offer_letter_details_proforma_id_key UNIQUE (proforma_id);
 c   ALTER TABLE ONLY public.offer_letter_details DROP CONSTRAINT offer_letter_details_proforma_id_key;
       public            postgres    false    451            !           2606    87488 -   organization organization_organization_id_key 
   CONSTRAINT     s   ALTER TABLE ONLY public.organization
    ADD CONSTRAINT organization_organization_id_key UNIQUE (organization_id);
 W   ALTER TABLE ONLY public.organization DROP CONSTRAINT organization_organization_id_key;
       public            postgres    false    401            #           2606    87490    organization organization_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.organization DROP CONSTRAINT organization_pkey;
       public            postgres    false    401            %           2606    87492 (   organization_type organization_type_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.organization_type
    ADD CONSTRAINT organization_type_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.organization_type DROP CONSTRAINT organization_type_pkey;
       public            postgres    false    403            )           2606    87494 &   proforma_details performa_details_pkey 
   CONSTRAINT     m   ALTER TABLE ONLY public.proforma_details
    ADD CONSTRAINT performa_details_pkey PRIMARY KEY (proforma_id);
 P   ALTER TABLE ONLY public.proforma_details DROP CONSTRAINT performa_details_pkey;
       public            postgres    false    407            '           2606    87496 8   profile_category_settings profile_category_settings_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.profile_category_settings
    ADD CONSTRAINT profile_category_settings_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.profile_category_settings DROP CONSTRAINT profile_category_settings_pkey;
       public            postgres    false    405            +           2606    87498 $   proforma_status proforma_status_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.proforma_status
    ADD CONSTRAINT proforma_status_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.proforma_status DROP CONSTRAINT proforma_status_pkey;
       public            postgres    false    409            -           2606    87500 *   qualification_type qualification_type_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.qualification_type
    ADD CONSTRAINT qualification_type_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.qualification_type DROP CONSTRAINT qualification_type_pkey;
       public            postgres    false    411            1           2606    87502 *   resume_achievement resume_achievement_pkey 
   CONSTRAINT     |   ALTER TABLE ONLY public.resume_achievement
    ADD CONSTRAINT resume_achievement_pkey PRIMARY KEY (resume_achievement_lid);
 T   ALTER TABLE ONLY public.resume_achievement DROP CONSTRAINT resume_achievement_pkey;
       public            postgres    false    414            3           2606    87504 :   resume_achievement resume_achievement_resume_lid_title_key 
   CONSTRAINT     ?   ALTER TABLE ONLY public.resume_achievement
    ADD CONSTRAINT resume_achievement_resume_lid_title_key UNIQUE (resume_lid, title);
 d   ALTER TABLE ONLY public.resume_achievement DROP CONSTRAINT resume_achievement_resume_lid_title_key;
       public            postgres    false    414    414            5           2606    87506 Q   resume_experience resume_experience_experience_type_lid_employer_name_start_d_key 
   CONSTRAINT     ?   ALTER TABLE ONLY public.resume_experience
    ADD CONSTRAINT resume_experience_experience_type_lid_employer_name_start_d_key UNIQUE (experience_type_lid, employer_name, start_date, end_date);
 {   ALTER TABLE ONLY public.resume_experience DROP CONSTRAINT resume_experience_experience_type_lid_employer_name_start_d_key;
       public            postgres    false    416    416    416    416            7           2606    87508 (   resume_experience resume_experience_pkey 
   CONSTRAINT     y   ALTER TABLE ONLY public.resume_experience
    ADD CONSTRAINT resume_experience_pkey PRIMARY KEY (resume_experience_lid);
 R   ALTER TABLE ONLY public.resume_experience DROP CONSTRAINT resume_experience_pkey;
       public            postgres    false    416            /           2606    87510    resume resume_pkey 
   CONSTRAINT     P   ALTER TABLE ONLY public.resume
    ADD CONSTRAINT resume_pkey PRIMARY KEY (id);
 <   ALTER TABLE ONLY public.resume DROP CONSTRAINT resume_pkey;
       public            postgres    false    413            9           2606    87512 4   resume_profile_category resume_profile_category_pkey 
   CONSTRAINT     r   ALTER TABLE ONLY public.resume_profile_category
    ADD CONSTRAINT resume_profile_category_pkey PRIMARY KEY (id);
 ^   ALTER TABLE ONLY public.resume_profile_category DROP CONSTRAINT resume_profile_category_pkey;
       public            postgres    false    419            ;           2606    87514 *   resume_publication resume_publication_pkey 
   CONSTRAINT     |   ALTER TABLE ONLY public.resume_publication
    ADD CONSTRAINT resume_publication_pkey PRIMARY KEY (resume_publication_lid);
 T   ALTER TABLE ONLY public.resume_publication DROP CONSTRAINT resume_publication_pkey;
       public            postgres    false    421            =           2606    87516 $   resume_research resume_research_pkey 
   CONSTRAINT     s   ALTER TABLE ONLY public.resume_research
    ADD CONSTRAINT resume_research_pkey PRIMARY KEY (resume_research_lid);
 N   ALTER TABLE ONLY public.resume_research DROP CONSTRAINT resume_research_pkey;
       public            postgres    false    425            ?           2606    87518 0   resume_skill_selected resume_skill_selected_pkey 
   CONSTRAINT     ?   ALTER TABLE ONLY public.resume_skill_selected
    ADD CONSTRAINT resume_skill_selected_pkey PRIMARY KEY (resume_skill_selected_lid);
 Z   ALTER TABLE ONLY public.resume_skill_selected DROP CONSTRAINT resume_skill_selected_pkey;
       public            postgres    false    427            A           2606    87520    role role_name_key 
   CONSTRAINT     M   ALTER TABLE ONLY public.role
    ADD CONSTRAINT role_name_key UNIQUE (name);
 <   ALTER TABLE ONLY public.role DROP CONSTRAINT role_name_key;
       public            postgres    false    429            C           2606    87522    role role_pkey 
   CONSTRAINT     L   ALTER TABLE ONLY public.role
    ADD CONSTRAINT role_pkey PRIMARY KEY (id);
 8   ALTER TABLE ONLY public.role DROP CONSTRAINT role_pkey;
       public            postgres    false    429            E           2606    87524    session_info session_info_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.session_info
    ADD CONSTRAINT session_info_pkey PRIMARY KEY (session_handle);
 H   ALTER TABLE ONLY public.session_info DROP CONSTRAINT session_info_pkey;
       public            postgres    false    431            G           2606    87526    skill skill_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.skill
    ADD CONSTRAINT skill_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.skill DROP CONSTRAINT skill_pkey;
       public            postgres    false    432            I           2606    87528    skill skill_skill_name_key 
   CONSTRAINT     [   ALTER TABLE ONLY public.skill
    ADD CONSTRAINT skill_skill_name_key UNIQUE (skill_name);
 D   ALTER TABLE ONLY public.skill DROP CONSTRAINT skill_skill_name_key;
       public            postgres    false    432            K           2606    87530    skill_type skill_type_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.skill_type
    ADD CONSTRAINT skill_type_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.skill_type DROP CONSTRAINT skill_type_pkey;
       public            postgres    false    434            Y           2606    104530    test test_pkey 
   CONSTRAINT     L   ALTER TABLE ONLY public.test
    ADD CONSTRAINT test_pkey PRIMARY KEY (id);
 8   ALTER TABLE ONLY public.test DROP CONSTRAINT test_pkey;
       public            postgres    false    449            S           2606    87532 &   user_application user_application_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.user_application
    ADD CONSTRAINT user_application_pkey PRIMARY KEY (appln_id);
 P   ALTER TABLE ONLY public.user_application DROP CONSTRAINT user_application_pkey;
       public            postgres    false    440            M           2606    87534    user user_email 
   CONSTRAINT     M   ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_email UNIQUE (email);
 ;   ALTER TABLE ONLY public."user" DROP CONSTRAINT user_email;
       public            postgres    false    438            U           2606    87536    user_gender user_gender_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.user_gender
    ADD CONSTRAINT user_gender_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.user_gender DROP CONSTRAINT user_gender_pkey;
       public            postgres    false    443            O           2606    87538    user user_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public."user" DROP CONSTRAINT user_pkey;
       public            postgres    false    438            W           2606    87540    user_role user_role_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.user_role
    ADD CONSTRAINT user_role_pkey PRIMARY KEY (user_lid, role_lid);
 B   ALTER TABLE ONLY public.user_role DROP CONSTRAINT user_role_pkey;
       public            postgres    false    447    447            Q           2606    87542    user user_user_id_key 
   CONSTRAINT     U   ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_user_id_key UNIQUE (user_id);
 A   ALTER TABLE ONLY public."user" DROP CONSTRAINT user_user_id_key;
       public            postgres    false    438            ?           2620    128307    proforma_details test_trigger    TRIGGER     ?   CREATE TRIGGER test_trigger AFTER UPDATE ON public.proforma_details FOR EACH ROW EXECUTE FUNCTION public.offer_letter_insert();
 6   DROP TRIGGER test_trigger ON public.proforma_details;
       public          postgres    false    554    407            f           2606    87543 9   application_resume_skill_selected application_resume_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.application_resume_skill_selected
    ADD CONSTRAINT application_resume_fkey FOREIGN KEY (resume_lid) REFERENCES public.resume(id);
 c   ALTER TABLE ONLY public.application_resume_skill_selected DROP CONSTRAINT application_resume_fkey;
       public          postgres    false    372    3887    413            g           2606    87548 8   application_resume_skill_selected application_skill_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.application_resume_skill_selected
    ADD CONSTRAINT application_skill_fkey FOREIGN KEY (skill_lid) REFERENCES public.skill(id);
 b   ALTER TABLE ONLY public.application_resume_skill_selected DROP CONSTRAINT application_skill_fkey;
       public          postgres    false    372    3911    432            d           2606    87553 @   application_resume_qualification appln_resume_qualification_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.application_resume_qualification
    ADD CONSTRAINT appln_resume_qualification_fkey FOREIGN KEY (application_lid) REFERENCES public.user_application(appln_id);
 j   ALTER TABLE ONLY public.application_resume_qualification DROP CONSTRAINT appln_resume_qualification_fkey;
       public          postgres    false    3923    440    368            m           2606    87558    bank_details fk_bank_type    FK CONSTRAINT     ?   ALTER TABLE ONLY public.bank_details
    ADD CONSTRAINT fk_bank_type FOREIGN KEY (bank_account_type_lid) REFERENCES public.bank_account_type(id);
 C   ALTER TABLE ONLY public.bank_details DROP CONSTRAINT fk_bank_type;
       public          postgres    false    3857    386    384            n           2606    87563    bank_details fk_resume_bank    FK CONSTRAINT     ~   ALTER TABLE ONLY public.bank_details
    ADD CONSTRAINT fk_resume_bank FOREIGN KEY (resume_lid) REFERENCES public.resume(id);
 E   ALTER TABLE ONLY public.bank_details DROP CONSTRAINT fk_resume_bank;
       public          postgres    false    386    3887    413            ?           2606    87568    user_info fk_resume_user    FK CONSTRAINT     {   ALTER TABLE ONLY public.user_info
    ADD CONSTRAINT fk_resume_user FOREIGN KEY (resume_lid) REFERENCES public.resume(id);
 B   ALTER TABLE ONLY public.user_info DROP CONSTRAINT fk_resume_user;
       public          postgres    false    3887    446    413            ?           2606    87573    user_address fk_resume_user    FK CONSTRAINT     ~   ALTER TABLE ONLY public.user_address
    ADD CONSTRAINT fk_resume_user FOREIGN KEY (resume_lid) REFERENCES public.resume(id);
 E   ALTER TABLE ONLY public.user_address DROP CONSTRAINT fk_resume_user;
       public          postgres    false    439    3887    413            ?           2606    87578    user_contact fk_resume_user    FK CONSTRAINT     ~   ALTER TABLE ONLY public.user_contact
    ADD CONSTRAINT fk_resume_user FOREIGN KEY (resume_lid) REFERENCES public.resume(id);
 E   ALTER TABLE ONLY public.user_contact DROP CONSTRAINT fk_resume_user;
       public          postgres    false    442    413    3887            o           2606    87583    bank_details fk_user_bank    FK CONSTRAINT     z   ALTER TABLE ONLY public.bank_details
    ADD CONSTRAINT fk_user_bank FOREIGN KEY (user_lid) REFERENCES public."user"(id);
 C   ALTER TABLE ONLY public.bank_details DROP CONSTRAINT fk_user_bank;
       public          postgres    false    3919    438    386            r           2606    87588    level level_role_lid    FK CONSTRAINT     s   ALTER TABLE ONLY public.level
    ADD CONSTRAINT level_role_lid FOREIGN KEY (role_lid) REFERENCES public.role(id);
 >   ALTER TABLE ONLY public.level DROP CONSTRAINT level_role_lid;
       public          postgres    false    3907    397    429            s           2606    87593 )   organization organization_campus_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.organization
    ADD CONSTRAINT organization_campus_lid_fkey FOREIGN KEY (campus_lid) REFERENCES public.campus(id);
 S   ALTER TABLE ONLY public.organization DROP CONSTRAINT organization_campus_lid_fkey;
       public          postgres    false    401    387    3859            p           2606    87598 %   discontinue_details organization_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.discontinue_details
    ADD CONSTRAINT organization_fkey FOREIGN KEY (organization_lid) REFERENCES public.organization(organization_id);
 O   ALTER TABLE ONLY public.discontinue_details DROP CONSTRAINT organization_fkey;
       public          postgres    false    3873    391    401            ^           2606    87603 '   admin_organization organization_id_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.admin_organization
    ADD CONSTRAINT organization_id_fkey FOREIGN KEY (organization_lid) REFERENCES public.organization(organization_id);
 Q   ALTER TABLE ONLY public.admin_organization DROP CONSTRAINT organization_id_fkey;
       public          postgres    false    3873    356    401            u           2606    87608 #   proforma_details perform_appln_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.proforma_details
    ADD CONSTRAINT perform_appln_fkey FOREIGN KEY (application_lid) REFERENCES public.user_application(appln_id);
 M   ALTER TABLE ONLY public.proforma_details DROP CONSTRAINT perform_appln_fkey;
       public          postgres    false    407    3923    440            v           2606    87613 %   proforma_details performa_status_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.proforma_details
    ADD CONSTRAINT performa_status_fkey FOREIGN KEY (status_lid) REFERENCES public.application_status(id);
 O   ALTER TABLE ONLY public.proforma_details DROP CONSTRAINT performa_status_fkey;
       public          postgres    false    407    3853    374            w           2606    87618    proforma_status proforma_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.proforma_status
    ADD CONSTRAINT proforma_fkey FOREIGN KEY (proforma_lid) REFERENCES public.proforma_details(proforma_id);
 G   ALTER TABLE ONLY public.proforma_status DROP CONSTRAINT proforma_fkey;
       public          postgres    false    409    3881    407            q           2606    87623 !   discontinue_details proforma_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.discontinue_details
    ADD CONSTRAINT proforma_fkey FOREIGN KEY (proforma_lid) REFERENCES public.proforma_details(proforma_id);
 K   ALTER TABLE ONLY public.discontinue_details DROP CONSTRAINT proforma_fkey;
       public          postgres    false    391    3881    407            l           2606    87628 %   approved_faculty_status proforma_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.approved_faculty_status
    ADD CONSTRAINT proforma_fkey FOREIGN KEY (proforma_lid) REFERENCES public.proforma_details(proforma_id);
 O   ALTER TABLE ONLY public.approved_faculty_status DROP CONSTRAINT proforma_fkey;
       public          postgres    false    382    3881    407            x           2606    87633 $   proforma_status proforma_status_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.proforma_status
    ADD CONSTRAINT proforma_status_fkey FOREIGN KEY (status_lid) REFERENCES public.application_status(id);
 N   ALTER TABLE ONLY public.proforma_status DROP CONSTRAINT proforma_status_fkey;
       public          postgres    false    409    3853    374            ?           2606    87638 :   resume_publication publication_resume_achievement_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.resume_publication
    ADD CONSTRAINT publication_resume_achievement_lid_fkey FOREIGN KEY (resume_achievement_lid) REFERENCES public.resume_achievement(resume_achievement_lid);
 d   ALTER TABLE ONLY public.resume_publication DROP CONSTRAINT publication_resume_achievement_lid_fkey;
       public          postgres    false    421    3889    414            ?           2606    87643 4   resume_research research_resume_achievement_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.resume_research
    ADD CONSTRAINT research_resume_achievement_lid_fkey FOREIGN KEY (resume_achievement_lid) REFERENCES public.resume_achievement(resume_achievement_lid);
 ^   ALTER TABLE ONLY public.resume_research DROP CONSTRAINT research_resume_achievement_lid_fkey;
       public          postgres    false    425    3889    414            z           2606    87648 ?   resume_achievement resume_achievement_achievement_type_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.resume_achievement
    ADD CONSTRAINT resume_achievement_achievement_type_lid_fkey FOREIGN KEY (achievement_type_lid) REFERENCES public.achievement_type(id);
 i   ALTER TABLE ONLY public.resume_achievement DROP CONSTRAINT resume_achievement_achievement_type_lid_fkey;
       public          postgres    false    414    3843    352            {           2606    87653 @   resume_achievement resume_achievement_organization_type_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.resume_achievement
    ADD CONSTRAINT resume_achievement_organization_type_lid_fkey FOREIGN KEY (organization_type_lid) REFERENCES public.organization_type(id);
 j   ALTER TABLE ONLY public.resume_achievement DROP CONSTRAINT resume_achievement_organization_type_lid_fkey;
       public          postgres    false    414    403    3877            |           2606    87658 5   resume_achievement resume_achievement_resume_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.resume_achievement
    ADD CONSTRAINT resume_achievement_resume_lid_fkey FOREIGN KEY (resume_lid) REFERENCES public.resume(id);
 _   ALTER TABLE ONLY public.resume_achievement DROP CONSTRAINT resume_achievement_resume_lid_fkey;
       public          postgres    false    3887    414    413            }           2606    87663 8   resume_experience resume_experience_designation_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.resume_experience
    ADD CONSTRAINT resume_experience_designation_lid_fkey FOREIGN KEY (designation_lid) REFERENCES public.designation(id);
 b   ALTER TABLE ONLY public.resume_experience DROP CONSTRAINT resume_experience_designation_lid_fkey;
       public          postgres    false    416    3861    389            ~           2606    87668 <   resume_experience resume_experience_experience_type_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.resume_experience
    ADD CONSTRAINT resume_experience_experience_type_lid_fkey FOREIGN KEY (experience_type_lid) REFERENCES public.experience_type(id);
 f   ALTER TABLE ONLY public.resume_experience DROP CONSTRAINT resume_experience_experience_type_lid_fkey;
       public          postgres    false    416    393    3865                       2606    87673 3   resume_experience resume_experience_resume_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.resume_experience
    ADD CONSTRAINT resume_experience_resume_lid_fkey FOREIGN KEY (resume_lid) REFERENCES public.resume(id);
 ]   ALTER TABLE ONLY public.resume_experience DROP CONSTRAINT resume_experience_resume_lid_fkey;
       public          postgres    false    3887    413    416            ?           2606    87678 ?   resume_profile_category resume_profile_category_parent_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.resume_profile_category
    ADD CONSTRAINT resume_profile_category_parent_lid_fkey FOREIGN KEY (parent_lid) REFERENCES public.resume_profile_category(id);
 i   ALTER TABLE ONLY public.resume_profile_category DROP CONSTRAINT resume_profile_category_parent_lid_fkey;
       public          postgres    false    419    419    3897            t           2606    87683 -   profile_category_settings resume_profile_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.profile_category_settings
    ADD CONSTRAINT resume_profile_fkey FOREIGN KEY (profile_category_id) REFERENCES public.resume_profile_category(id);
 W   ALTER TABLE ONLY public.profile_category_settings DROP CONSTRAINT resume_profile_fkey;
       public          postgres    false    3897    419    405            ?           2606    87688 E   resume_qualification resume_qualification_qualification_type_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.resume_qualification
    ADD CONSTRAINT resume_qualification_qualification_type_lid_fkey FOREIGN KEY (qualification_type_lid) REFERENCES public.qualification_type(id);
 o   ALTER TABLE ONLY public.resume_qualification DROP CONSTRAINT resume_qualification_qualification_type_lid_fkey;
       public          postgres    false    423    3885    411            ?           2606    87693 9   resume_qualification resume_qualification_resume_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.resume_qualification
    ADD CONSTRAINT resume_qualification_resume_lid_fkey FOREIGN KEY (resume_lid) REFERENCES public.resume(id);
 c   ALTER TABLE ONLY public.resume_qualification DROP CONSTRAINT resume_qualification_resume_lid_fkey;
       public          postgres    false    3887    423    413            ?           2606    87698 ;   resume_skill_selected resume_skill_selected_resume_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.resume_skill_selected
    ADD CONSTRAINT resume_skill_selected_resume_lid_fkey FOREIGN KEY (resume_lid) REFERENCES public.resume(id);
 e   ALTER TABLE ONLY public.resume_skill_selected DROP CONSTRAINT resume_skill_selected_resume_lid_fkey;
       public          postgres    false    413    3887    427            ?           2606    87703 :   resume_skill_selected resume_skill_selected_skill_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.resume_skill_selected
    ADD CONSTRAINT resume_skill_selected_skill_lid_fkey FOREIGN KEY (skill_lid) REFERENCES public.skill(id);
 d   ALTER TABLE ONLY public.resume_skill_selected DROP CONSTRAINT resume_skill_selected_skill_lid_fkey;
       public          postgres    false    3911    432    427            y           2606    87708    resume resume_user_lid_fkey    FK CONSTRAINT     |   ALTER TABLE ONLY public.resume
    ADD CONSTRAINT resume_user_lid_fkey FOREIGN KEY (user_lid) REFERENCES public."user"(id);
 E   ALTER TABLE ONLY public.resume DROP CONSTRAINT resume_user_lid_fkey;
       public          postgres    false    3919    413    438            `           2606    87713 .   application_bank_details rev_bank_details_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.application_bank_details
    ADD CONSTRAINT rev_bank_details_fkey FOREIGN KEY (application_lid) REFERENCES public.user_application(appln_id);
 X   ALTER TABLE ONLY public.application_bank_details DROP CONSTRAINT rev_bank_details_fkey;
       public          postgres    false    3923    440    360            a           2606    87718 :   application_resume_achievement rev_resume_achievement_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.application_resume_achievement
    ADD CONSTRAINT rev_resume_achievement_fkey FOREIGN KEY (application_lid) REFERENCES public.user_application(appln_id);
 d   ALTER TABLE ONLY public.application_resume_achievement DROP CONSTRAINT rev_resume_achievement_fkey;
       public          postgres    false    362    3923    440            b           2606    87723 8   application_resume_experience rev_resume_experience_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.application_resume_experience
    ADD CONSTRAINT rev_resume_experience_fkey FOREIGN KEY (application_lid) REFERENCES public.user_application(appln_id);
 b   ALTER TABLE ONLY public.application_resume_experience DROP CONSTRAINT rev_resume_experience_fkey;
       public          postgres    false    3923    364    440            c           2606    87728 :   application_resume_publication rev_resume_publication_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.application_resume_publication
    ADD CONSTRAINT rev_resume_publication_fkey FOREIGN KEY (application_lid) REFERENCES public.user_application(appln_id);
 d   ALTER TABLE ONLY public.application_resume_publication DROP CONSTRAINT rev_resume_publication_fkey;
       public          postgres    false    3923    366    440            e           2606    87733 4   application_resume_research rev_resume_research_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.application_resume_research
    ADD CONSTRAINT rev_resume_research_fkey FOREIGN KEY (application_lid) REFERENCES public.user_application(appln_id);
 ^   ALTER TABLE ONLY public.application_resume_research DROP CONSTRAINT rev_resume_research_fkey;
       public          postgres    false    3923    370    440            h           2606    87738 @   application_resume_skill_selected rev_resume_skill_selected_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.application_resume_skill_selected
    ADD CONSTRAINT rev_resume_skill_selected_fkey FOREIGN KEY (application_lid) REFERENCES public.user_application(appln_id);
 j   ALTER TABLE ONLY public.application_resume_skill_selected DROP CONSTRAINT rev_resume_skill_selected_fkey;
       public          postgres    false    372    440    3923            i           2606    87743 .   application_user_address rev_user_address_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.application_user_address
    ADD CONSTRAINT rev_user_address_fkey FOREIGN KEY (application_lid) REFERENCES public.user_application(appln_id);
 X   ALTER TABLE ONLY public.application_user_address DROP CONSTRAINT rev_user_address_fkey;
       public          postgres    false    376    440    3923            j           2606    87748 .   application_user_contact rev_user_contact_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.application_user_contact
    ADD CONSTRAINT rev_user_contact_fkey FOREIGN KEY (application_lid) REFERENCES public.user_application(appln_id);
 X   ALTER TABLE ONLY public.application_user_contact DROP CONSTRAINT rev_user_contact_fkey;
       public          postgres    false    440    3923    378            k           2606    87753 (   application_user_info rev_user_info_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.application_user_info
    ADD CONSTRAINT rev_user_info_fkey FOREIGN KEY (application_lid) REFERENCES public.user_application(appln_id);
 R   ALTER TABLE ONLY public.application_user_info DROP CONSTRAINT rev_user_info_fkey;
       public          postgres    false    380    3923    440            ?           2606    87758 &   session_info session_info_user_id_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.session_info
    ADD CONSTRAINT session_info_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."user"(user_id);
 P   ALTER TABLE ONLY public.session_info DROP CONSTRAINT session_info_user_id_fkey;
       public          postgres    false    3921    438    431            ?           2606    87763 '   session_info session_info_user_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.session_info
    ADD CONSTRAINT session_info_user_lid_fkey FOREIGN KEY (user_lid) REFERENCES public."user"(id);
 Q   ALTER TABLE ONLY public.session_info DROP CONSTRAINT session_info_user_lid_fkey;
       public          postgres    false    431    438    3919            ?           2606    87768    skill skill_skill_type_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.skill
    ADD CONSTRAINT skill_skill_type_lid_fkey FOREIGN KEY (skill_type_lid) REFERENCES public.skill_type(id);
 I   ALTER TABLE ONLY public.skill DROP CONSTRAINT skill_skill_type_lid_fkey;
       public          postgres    false    434    3915    432            ?           2606    87773 /   user_address user_address_address_type_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.user_address
    ADD CONSTRAINT user_address_address_type_lid_fkey FOREIGN KEY (address_type_lid) REFERENCES public.address_type(id);
 Y   ALTER TABLE ONLY public.user_address DROP CONSTRAINT user_address_address_type_lid_fkey;
       public          postgres    false    439    354    3845            ?           2606    87778 '   user_address user_address_user_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.user_address
    ADD CONSTRAINT user_address_user_lid_fkey FOREIGN KEY (user_lid) REFERENCES public."user"(id);
 Q   ALTER TABLE ONLY public.user_address DROP CONSTRAINT user_address_user_lid_fkey;
       public          postgres    false    438    3919    439            ?           2606    87783 1   user_application user_application_resume_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.user_application
    ADD CONSTRAINT user_application_resume_lid_fkey FOREIGN KEY (resume_lid) REFERENCES public.resume(id);
 [   ALTER TABLE ONLY public.user_application DROP CONSTRAINT user_application_resume_lid_fkey;
       public          postgres    false    413    3887    440            ?           2606    87788 '   user_contact user_contact_user_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.user_contact
    ADD CONSTRAINT user_contact_user_lid_fkey FOREIGN KEY (user_lid) REFERENCES public."user"(id);
 Q   ALTER TABLE ONLY public.user_contact DROP CONSTRAINT user_contact_user_lid_fkey;
       public          postgres    false    438    3919    442            ?           2606    87793 #   user_info user_info_gender_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.user_info
    ADD CONSTRAINT user_info_gender_lid_fkey FOREIGN KEY (gender_lid) REFERENCES public.user_gender(id);
 M   ALTER TABLE ONLY public.user_info DROP CONSTRAINT user_info_gender_lid_fkey;
       public          postgres    false    443    3925    446            ?           2606    87798 !   user_info user_info_user_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.user_info
    ADD CONSTRAINT user_info_user_lid_fkey FOREIGN KEY (user_lid) REFERENCES public."user"(id);
 K   ALTER TABLE ONLY public.user_info DROP CONSTRAINT user_info_user_lid_fkey;
       public          postgres    false    446    3919    438            _           2606    87803     admin_organization user_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.admin_organization
    ADD CONSTRAINT user_lid_fkey FOREIGN KEY (user_lid) REFERENCES public."user"(id);
 J   ALTER TABLE ONLY public.admin_organization DROP CONSTRAINT user_lid_fkey;
       public          postgres    false    438    356    3919            ?           2606    87808 !   user_role user_role_role_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.user_role
    ADD CONSTRAINT user_role_role_lid_fkey FOREIGN KEY (role_lid) REFERENCES public.role(id);
 K   ALTER TABLE ONLY public.user_role DROP CONSTRAINT user_role_role_lid_fkey;
       public          postgres    false    447    429    3907            ?           2606    87813 !   user_role user_role_user_lid_fkey    FK CONSTRAINT     ?   ALTER TABLE ONLY public.user_role
    ADD CONSTRAINT user_role_user_lid_fkey FOREIGN KEY (user_lid) REFERENCES public."user"(id);
 K   ALTER TABLE ONLY public.user_role DROP CONSTRAINT user_role_user_lid_fkey;
       public          postgres    false    447    3919    438            !   B   x?3?(M??LN,???+????΂?$.cΠ???Ģ??0??e??X?X??P?X^?????? ?,?      #   2   x?3?H-?M?K?+QpLI)J-.?,?2?t?/??S??S?db???? ???      %   ;   x?Mʻ  ??(??Y?e????]?&??????n{?HJY?:??Gw?MG{?w?xdY      '      x?????? ? ?      )      x?????? ? ?      +      x?????? ? ?      -      x?????? ? ?      /      x?????? ? ?      1      x?????? ? ?      3      x?????? ? ?      5      x?????? ? ?      7   F   x?3?tLNN-(IM?,?2?J?JM?pL8????S?Jsr*?s???(??)??eg??Ec???? ?z?      9      x?????? ? ?      ;      x?????? ? ?      =      x?????? ? ?      ?      x?????? ? ?      A   v   x?3?t.-*J?+QpL??/?+?,?tv?2?N,??K/
'C??"???\?@FNbQ%?LHƄ?/?O7(?83h`fb??QJf?? ?RSΠ?d??@+\R??3K???A??qqq 9?2e      C      x?????? ? ?      D   B   x?3?4500027?,N????
????9
???I???1~?%\FPef`ey(???2u???qqq rM?      F   ?   x?e??
?@???S?d?V?1L?"A?.?:?P???Qo??I?>?"8`J)??
3?5???w?@?W>-`Gj6_`	ǉ`???:R??sY~?5??W-????m ???Q?L7UӐ??"	{T??E??????(???dY?,?i?Zg??|)??4????+	???K.
??+????0?'f?U      H      x?????? ? ?      J   p   x?3?tI-?L?K,????????e??ZQ?Z??????&e?陗RZ\R????????(3/%>???˔3$519#3/???,X?1gx~Q6PUjQ??4U^?V???? S?6r      L   M   x?3?twQ?M-??O19K??8???b 6PИ3?1??.
? ?M8C\C\a?P????!?%b???? m?B      N   ;   x?ȱ?0????L??%Y?%??7ā?X?&????n???9l???R?¦5&X?I??g      P     x??XMs?H]?_??d?E???Q?
`	q?U??aF?????_?@BD???T?>?????{(?t?절ra?>??W??1NC,?Ӊ?)?$x8?y?3`	P(???,&???>(Ӄ???;a?????n?? ?i???]? ???p76?-?i??i?CI??*?"???????@u?e&7D??*?7??g??)???j?^??????rLsc9˪RS?????V???3?r?\]sM?,?`w
??ہ$?S???????:#!??8ݏtjT? T?Z?
R???bD8??";]glm??.]???C????O?f?V?3?9???s??}?????
V/a?c?6? ???ü)1?$?V?"O?$e?,??M?F?e?Y????????̆?Yy?KM?????B??W???^<??y ?m˱<S??j???AK?6???i	??W?9ל??
?n????ڧ????&?Y???\C??? ̺6??[a??%nS??
s?-s3j5??S[??Z?ĕ?k?v????.M??p?irB	6?Ч??)ʽ?0????ϔ?
2?OEDR??xm?0?S???<ާ??R?gv?H|?1???\?w`n?#?%dwJ???̫???
??\??J??1???????5}Z???e?lp?n?+Wt?%_????Ȱ???
[ka??֔?}?M??N?ڹ????????S?i??S?cAU?gQ?cZp?T?????I??>??k?*yi??C/!5????q?%??[?gc{썟FTP3c?=?U?#HSI?vNM???"msc?`?a?/?O%	?3?A??FC??????4??B???m???$81x\??????j(?ی5?j4ߖD? =/ݍ??l?	?(3??/ ??'Y\D??S????t{!_坼v?0?x??w?!(?O
?>?ά?v <??1 ?vR??iQ??r?????%?Oi?r	i;I_IVv?????H??zM?X??F??V5C6Z??w`?ʽ?L???k\?UŚ\??E?2??5??????o??\V?~{???e??????~?Q?      ?   ?   x?}??N?@E?ٯ??jg?9?%???? ?H?2Q881A?CKX??=w?????Db?AbL?$ʐ!??!?M???*??????J??@?U?ɱr??ǻj????=6/ϛ'??r:J?d|B?X{6??g`??kٞ??/?Wy??A?]W?W?3|?r8˨xg?s?I????4D??2??r??͈??B??WnDKI??4󟔱(? J?H[c?      R   ?  x???]o?8???_??Yi??\:?KL?$¡??????*????????J;R)|??yϱ-c9?Ng?tn|KȪ?z?D?S%???D?x???NXz???r??l?L??5@??X?%?_>4Ů/??Q?]!??lQ.wǪ.??;p8???x?$???l?9???0?q?j??>%?2?|?,c??g7K????d?"&*q?'ب??l???=3g?MD?J?X]?oA]?? *?O'??$"???OŮE_pߩ??o? l??hְ\??w????&??:?
?L?,R6Eu J???8sÚyy??&?D'K????v?M?*˴؅ጊfb2?Q??(1C3???lC?E??Hp´?K?????P}Sg??ߏ?N%?BW'J?~?t???1J?5⭨?JT??'!b?CEf? ?]c?q?^`?<~|??rԽ1?U?,+Hk%?`?zxr??N??OM7?f/H?7??1?ф?4?????UH???o??$???8U???`?igwҪ튮?$J_~]oMu???1+?G?,?«-????{??8FY??$????wc??8ǋ?UE	?Z?\]?ʏ?T??7W???C,?Y?q???	?Z=x?3???O????GJF
?ȷ`KH
???N???????$?Ԅ??k P???C??[?? ???~>
?pe'^?Cq????>?????%?x??6?U???e?¡?pNbm?C??8]=A.?"??.$Yф?MV g??e{?;]?r2?G?;i????WDx?B?l{??6?I?֠_?\??)cd?F??I?&)???5??I??g/?q??36	????'?~-???w?%??օ????>?ae?2?P?ߥD??̱<w8??C??L???t?J?u???!|}??-?J?~	??M2}?r\???L??kha?(?.o\<Ku???Sջab?A??[m?m??۠
?z9???q??{??~CDZ??Fjw??f?}T????y??:??B#x#a??u????B??J??kM?X?<?? ?ՓT]#_??ɾi??+??
݋SQ???f??t?k˴???hz{;?d??r?9a??ԓ?q?????,i?C[H7?"?&M?B??*ngD߭=P,{????5??㟝???t??1?<????j???<???9`[?3q??i??????DYt????tU#`???L?4Qk??7?tE;v^?W73????'???      T   ?   x?3?,N????????,?u??8K?2?R??3K*!?e?\Ɯ?y)??%EP1?+F??? <=;      V   L   x?M??	?0?w<L??Ĵ?t??O?B>?BF?w?#>???????
U ??)W???!?Q???J??z?v3??I      X      x?????? ? ?      Z      x?????? ? ?      \   d   x?3??M,.I-R/VpIM/JM?????\?8?1g@???\? #?ː?)19#5'??$??	g@Q~Zjqqf~^b??sjQIfZfrb	?_?0.?+F??? ??(?      ^      x?????? ? ?      _      x?????? ? ?      a      x?????? ? ?      d   ?  x???Qo?0ǟϟ?o<Qb'Y??B??T(??I??\Zk!)???c???,Y??J{??ߝ??W_Q?Bf?Ⱥ[??5G??t*??2??UEp?~??7????kܣ??;Y?????b??.b??&;J????2v?m?{{C7??uГ??h	??{B%??~????R{????,???Q????}m??C??Q?ݟy???x????U???cU?t?Y??P??.:??u?Ӧ??I???n?s???????M?+?zl?1?????î`_?vͥ?r?????^?????`8a|??~
QwH
?O??CS??[?,k?J?-?y?uڿ?g2w
a痰Sua?cߊ??Ce?{F???r?/??w?,I??&G?O?;??Ǆqآ??j?????SG2?E??ë~2?ʔjaW ???FI???*?me?MF?|C7?????4Įaw\??3$?$=L???$??]͂?y ??!?J%?      f      x?????? ? ?      h      x?????? ? ?      j      x?????? ? ?      l      x?????? ? ?      n   d   x?3?-N-?,?2???q?wt???r?!\WG?*d?Be@l3(?3??9?$bqv?	r?
X@?\?=??B 5?P??K; ̉???? ?$?      p      x?????? ? ?      q   :  x?eT]o?0}???Ӷ?j? ?ۀ??*h?Ru/?$?x?mbG???????J?I ??ߏs?u4?+%??N7"{?U??dD???ukt.?????k??W&?GV{???h?]p?ɧ??p?Q9Y???~'.+?D??쯦?Xֽ????T?).??*?)Ś:-?&?+k|pm??}5EK"D9?t????&?a?????s?^I??`?ܑ?V??????8EMv:p?)!wJ?O?=r????b??΂?????nkj?qvc%?=?`I???Ơ??&?ؠ?-?o?G??Q???W???l???j_*'?u?4?G?>甸Sb?}Pf?r?FoTi?~?t???*?????????qB??m???o?ߺP&Ǹ?!!??Q?8???)?=D?!?s?X뾨J?.nq??e?	Ý??^?????#>Vs$m???ߠ?CF??Q?M??Q6?54???vd'}?t?ߣ?f?@?P$?8??x???H_8c"Y???2E?+iʖ??T?	S??bW?}?r???}?4??????K?1?3??$)k?u:W?`@?T?H`!<-p?ZM@??z>?X?
=?Hz?ܖf???OAt?nK?E?L`?b???z??6????ӻ????a?F?Yc]???V?????S>?Y?mm??~? ?~?m??Ud?????`?Ww?(?q?t????	??n????o?u?r?j|?{?G)H?_p^?%??{????1??&?W?2?`m?ŧ;Io?l?k~?,??Ι"&??f??F=????އ?ɔ??!????>?b???u?B?????%=??~}?G?!k?[ڶ?GC4t????????<;99?Tr??      s   (   x?3??O+Q????)????.#N?Ģt?=... c?7      ?   ?   x?E?;?0 ?zs??@?|?????l?WB??????y????ے??%?ףXz?Z??z??`L!bhdݎ?A	%?8s9??C?:??k??Ǵ!??f???????s?/? ?@\??xo?ȍ??{?g9??0;??`z??c?? ?a2}      ?   "   x?3?446?4500?047?423?,?????? :?>      ?      x?3??t?????? P7      u   Y   x?3?423?45?4?????H?T(NMU?MU?????K	##ה̒?NC#cNG??|?(????2?B??????N#C???=... ?X?      ?   <   x?3?44??4????J?M?L?K???ciIF~Qj
??_bY^f	????	P?+F??? 64?      ?   o   x?-?1? ??z8?^ ? ѥ?????f???Ac??Q?ɫ????zp?L?#??؄?AR?v۵|s!??Q[y??>?9Un?!?c?9x????)???0????5v??tJ?A?!?      ?   ?   x?3??VJT?RPJR?QPJ?R?j??? f?R-?H?!X?X&ȮVJ?d(??r??qqq J?       w   ?  x???Ɏ?z?5??`?-??1%?4?X2	8`:逢8???(O?o-?꛸??y?_??? OM??Pa????j_?5}~"??r? ???????F?ܳ???h2????j?'??@655
?k^????^lAS??l[???O??+7{?? ? /?HD C??u??Ev??C\̳xǤ??G????.?'?X*?%???G????麲]o???+h\JA?9_?t?/sYuF?F?O ??sɁ?T?k??]??b?$ J?e ?+RIV??m̬??bͨ??^
?g?lAD?Gҡ??|E??*:E5????ִg?m8?ǹ?f?H?p???>?C??ARz?B-#Y:??b	?F??c???????ئ?????IY??[??H 3??-???XI?T?p??c???3????!嘆??Z:x??G??o?#)???MlŞ?kZQx??ɹìi??????ym)co??????x~???????.??渏@??}bbJU?P?1?GL?d9Z??e??2O??2
e?BU?f????sm???*?&G?*sw?n?v?7???f?{b?????X?2?/???~"D'?ޠ?#?ҭ???)??N?:?St?j??~%:??8M=???:?Դ47?gfp?Dn?\^f?Pޠ, ?z???S?<52]ϻI????u???|??a?u??h?B??^?{?/(Q???y??v??rح??ِ?aO???????πm??D ?@0??c????T?t?QL0???:E?1???&??	??d??i[O?vu??
????"?W2??j:??[#??J??@??
??ԇ?#ZD??P?l??[y?GP?yߞ?????h????U31????Ժ\4?<??B4??y]?6ipY?{??????????9wKwDB(?6??W_uB_???[B?3 ?ێ2X@?O?? *p?_?????}x?C?}?䫺?1}?@??Y[?t??????;?$?_?T??~?>?d????F?5      x      x?????? ? ?      y      x?????? ? ?      {      x?????? ? ?      |   %   x?3??M?I?,?2?tKͅ0?9?K2R???=... ?\?            x?????? ? ?      ?   A   x?ʱ?0?Z&/X`?.??`???)aa3??(F?0
??!?J???z?5j?q??[?=$?
?     