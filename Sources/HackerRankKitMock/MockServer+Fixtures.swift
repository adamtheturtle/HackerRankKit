//
//  MockServer+Fixtures.swift
//  HackerRankKit
//
//  The fake API's canned fixture data: deterministic, sanitized demo records for the
//  HackerRank for Work endpoints. No real personal data.
//

import Foundation

// The fixtures below are verbatim API payloads held in raw string literals. Wrapping the
// JSON to fit a line limit would stop it matching what the service actually returns, and
// a disable comment cannot be placed inside a string literal.
// swiftlint:disable line_length

/// The fake API's canned fixture data. Everything is immutable seed data, safe to read
/// from any thread.
public nonisolated enum MockFixtures {
    // MARK: - Write acknowledgements

    /// The record returned when a candidate is invited in the demo. The invite UI shows
    /// the email the user typed, so this canned echo only needs to decode cleanly.
    static let createdCandidate = #"""
    {"id":"c-invited","email":"invited@example.com","status":0,"ats_state":0}
    """#

    /// The record returned when a user is created in the demo.
    static let createdUser = #"""
    {"id":"u-created","email":"created@example.com","role":"recruiter","status":"invited"}
    """#

    /// The record returned when a question is created/updated/deleted in the demo.
    static let writtenQuestion = #"""
    {"id":"q-written","name":"New Question","type":"code"}
    """#

    /// The acknowledgement returned for a question's codestub and testcase writes in the
    /// demo. These endpoints answer with an operation status rather than the question.
    static let questionOperationResult = #"""
    {"id":"qop-1","status":"ok","message":"Question operation completed"}
    """#

    /// The templates returned by the codestub generation endpoint in the demo. This route
    /// answers with the generated signature and one head/body/tail template per language,
    /// keyed by language name — not with an operation status.
    static let generatedCodeStubs = #"""
    {"functionName":"twoSum","functionParams":"INTEGER_ARRAY nums INTEGER target",
     "functionReturn":"INTEGER_ARRAY","allowedLanguages":"c, clojure","templateType":"function",
     "c_template_head":"#include <stdio.h>\n","c_template":"int* twoSum(int* nums, int target) {\n\n}\n",
     "c_template_tail":"int main() { return 0; }\n",
     "clojure_template_head":"(ns Solution)\n","clojure_template":"(defn twoSum [nums target]\n)\n",
     "clojure_template_tail":"(solve)\n"}
    """#

    /// The acknowledgement returned when an interview template is deleted in the demo.
    static let deletedInterviewTemplate = #"""
    {"message":"Success"}
    """#

    /// The acknowledgement returned when an interview template's explicit sharing roles
    /// are granted or revoked in the demo.
    static let interviewTemplateSharing = #"""
    {"model":[],"status":true,"message":"Successfully updated"}
    """#

    /// The record returned when a team is created in the demo.
    static let createdTeam = #"""
    {"id":"tm-created","name":"New Team","owner":"u1"}
    """#

    /// The record returned when an interview is created in the demo.
    static let createdInterview = #"""
    {"id":"i-created","url":"https://www.hackerrank.com/x/interviews/i-created","status":"scheduled"}
    """#

    /// The record returned when an ATS invite is created in the demo.
    static let atsInvite = #"""
    {"id":"ats-created","url":"https://www.hackerrank.com/x/ats/ats-created","status":"created","email":"ada@example.com"}
    """#

    /// The record returned when a test is created/updated/deleted in the demo.
    static let createdTest = #"""
    {"id":"t-created","name":"New Test","state":"draft"}
    """#

    // MARK: - Tests

    /// Page one of the tests list. Window keys and `sections` match what a live account
    /// returns (`start_time`/`end_time`, and an array of section objects). The decoder also
    /// accepts the schema's `starttime`/`endtime` and object-shaped `sections`.
    static let testsPage1 = #"""
    {"data":[
      {"id":"t1","unique_id":"backend-screen","name":"Backend Engineer Screen","state":"active",
       "start_time":"2026-05-01T09:00:00Z","end_time":"2026-06-01T09:00:00Z","duration":90,
       "languages":["python","go","java"],"cutoff_score":70,"tags":["backend","screening"],
       "library":"HackerRank","role_ids":["Backend Engineer"],"experience":["Senior"],
       "skills":["APIs","Data Structures"],"type":"Screen",
       "candidate_details":["full_name","university"],"custom_acknowledge_text":"I will not seek outside help.",
       "hide_compile_test":false,"hide_template":false,"enable_acknowledgement":true,
       "enable_advanced_proctoring":true,"enable_secure_assessment_mode":false,
       "enable_ml_plagiarism_analysis":true,"enable_photo_identification":true,
       "test_admins":["u1","u2"],"ide_config":"default",
       "enable_proctoring":true,"instructions":"Solve all questions within the time limit.","questions":["q1","q2"],
       "sections":[{"uuid":"s1","name":"Coding","questions":2,"duration":60},
                   {"uuid":"s2","name":"Multiple Choice","questions":5,"duration":30}]},
      {"id":"t2","unique_id":"frontend-takehome","name":"Frontend Take-Home","state":"active",
       "start_time":"2026-05-10T09:00:00Z","duration":120,"languages":["javascript","typescript"],
       "cutoff_score":65,"tags":["frontend"],"library":"HackerRank","role_ids":["Frontend Engineer"],
       "skills":["React","Accessibility"],"type":"Take Home"},
      {"id":"t3","unique_id":"ds-quiz","name":"Data Structures Quiz","state":"archived",
       "duration":45,"languages":["cpp"],"cutoff_score":80,"tags":["algorithms","mcq"],
       "library":"HackerRank","role_ids":["General Engineering"],"skills":["Algorithms"],"type":"Quiz"}
    ],"next":"https://www.hackerrank.com/x/api/v3/tests?limit=3&offset=3"}
    """#

    static let testsPage2 = #"""
    {"data":[
      {"id":"t4","unique_id":"sre-screen","name":"SRE On-Call Screen","state":"active",
       "start_time":"2026-05-15T09:00:00Z","duration":75,"languages":["python","bash"],
       "cutoff_score":72,"tags":["sre","backend"],"library":"HackerRank","role_ids":["SRE"],
       "skills":["Incident Response","Shell"],"type":"Screen","draft":true},
      {"id":"t5","unique_id":"ml-fundamentals","name":"ML Fundamentals","state":"active",
       "duration":60,"languages":["python"],"cutoff_score":68,"tags":["ml"],"library":"HackerRank",
       "role_ids":["Machine Learning Engineer"],"skills":["Machine Learning","Python"],"type":"Screen",
       "locked":true,"locked_by":"u1"}
    ],"next":null}
    """#

    /// The richer single-test read: candidate login links, the (sensitive) shared access
    /// password, and MCQ scoring over the list shape.
    static let testDetail = #"""
    {"id":"t1","unique_id":"backend-screen","name":"Backend Engineer Screen","state":"active",
     "start_time":"2026-05-01T09:00:00Z","end_time":"2026-06-01T09:00:00Z",
     "duration":90,"languages":["python","go","java"],"cutoff_score":70,"ide_config":"default",
     "short_login_url":"https://hr.gs/backend-screen",
     "public_login_url":"https://www.hackerrank.com/tests/backend-screen/login",
     "master_password":"demo-master-pw","mcq_correct_score":4.0,"mcq_incorrect_score":-1.0}
    """#

    /// Users who can invite candidates to the test.
    static let testInviters = #"""
    {"data":[
      {"id":"u1","email":"rhea@example.com","firstname":"Rhea","lastname":"Recruiter","role":"recruiter"},
      {"id":"u2","email":"ian@example.com","firstname":"Ian","lastname":"Interviewer","role":"interviewer"},
      {"id":"u-missing-email","firstname":"Email","lastname":"Optional","role":"recruiter"}
    ],"next":null}
    """#

    // MARK: - Candidates

    static let candidates = #"""
    {"data":[
      {"id":"c1","email":"ada@example.com","full_name":"Ada Lovelace","score":92.0,
       "percentage_score":92.0,"integrity_status":"clean","plagiarism_status":false,
       "status":7,"ats_state":2,
       "report_url":"https://www.hackerrank.com/x/candidates/c1/report",
       "pdf_url":"https://www.hackerrank.com/x/candidates/c1/report.pdf",
       "attempt_starttime":"2026-05-02T10:00:00Z","attempt_endtime":"2026-05-02T11:15:00Z",
       "tags":["shortlist"],"feedback":"Excellent problem decomposition."},
      {"id":"c2","email":"alan@example.com","full_name":"Alan Turing","score":81.5,
       "percentage_score":81.5,"integrity_status":"clean","plagiarism_status":false,
       "status":0,
       "attempt_starttime":"2026-05-03T14:00:00Z","attempt_endtime":"2026-05-03T15:10:00Z"},
      {"id":"c3","email":"grace@example.com","full_name":"Grace Hopper","score":58.0,
       "percentage_score":58.0,"integrity_status":"review","plagiarism_status":true,
       "status":7,"ats_state":22,"out_of_window_events":4,"out_of_window_duration":95.0,
       "editor_paste_count":7,
       "attempt_starttime":"2026-05-04T08:30:00Z"},
      {"id":"c4","email":"katherine@example.com","full_name":"Katherine Johnson","score":74.0,
       "percentage_score":74.0,"integrity_status":"clean","plagiarism_status":false,
       "attempt_starttime":"2026-05-06T09:00:00Z","attempt_endtime":"2026-05-06T10:30:00Z",
       "tags":["onsite","strong-math","follow-up"],
       "feedback":"Solid grasp of the core algorithm and a clean, well-tested implementation. Recommend advancing."},
      {"id":"c5","email":"noname@example.com"}
    ],"next":null}
    """#

    /// The richer single-candidate read. It is intentionally one object, not the paged
    /// `{"data":[...]}` envelope used by `/candidates`, and it carries the invite,
    /// integrity, and per-question fields the detail endpoint returns.
    static let candidateDetail = #"""
    {"id":"c1","email":"ada@example.com","full_name":"Ada Lovelace","score":92.0,
     "percentage_score":92.0,"integrity_status":"Low","plagiarism_status":false,
     "integrity_summary":"No integrity signals detected.","user":"u1","test":"t1",
     "status":7,"ats_state":2,
     "report_url":"https://www.hackerrank.com/x/candidates/c1/report",
     "authenticated_report_url":"https://www.hackerrank.com/x/candidates/c1/report?auth=1",
     "pdf_url":"https://www.hackerrank.com/x/candidates/c1/report.pdf",
     "attempt_starttime":"2026-05-02T10:00:00Z","attempt_endtime":"2026-05-02T11:15:00Z",
     "attempt_events":[{"id":1,"event":1,"inserttime":"2026-05-02T10:00:00Z"}],
     "invite_email_done":true,"invite_valid":true,"invited_on":"2026-05-01T09:00:00Z",
     "invite_valid_from":"2026-05-01T09:00:00Z","invite_valid_to":"2026-05-08T09:00:00Z",
     "invite_link":"https://www.hackerrank.com/tests/backend-screen/login?id=c1",
     "invite_metadata":{"source":"careers-site"},"evaluator_email":"ian@example.com",
     "test_finish_url":"https://example.com/thanks","test_result_url":"https://example.com/webhook",
     "accept_result_updates":true,
     "scores_tags_split":{"backend":60},"scores_skills_split":{"APIs":32},
     "added_time":"30","unclaimed_added_time":10,
     "comments":{"summary":"Strong candidate."},
     "performance_summary":"Solved both questions comfortably within time.",
     "ip_address":"203.0.113.7",
     "questions":{"q1":{"score":50.0,"answered":true,"name":"Two Sum"},
                  "q2":{"score":42.0,"answered":true,"name":"LRU Cache"}},
     "candidate_details":[{"field_name":"university","title":"University","value":"Example University"}],
     "proctor_images":["https://www.hackerrank.com/x/candidates/c1/proctor/1.jpg"],
     "tags":["shortlist","single-read"],"feedback":"Excellent problem decomposition.",
     "out_of_window_events":0,"out_of_window_duration":0.0,"editor_paste_count":1}
    """#

    // MARK: - Questions

    static let questions = #"""
    {"data":[
      {"id":"q1","unique_id":"two-sum","type":"code","name":"Two Sum","status":"published",
       "languages":["python","go","java"],"max_score":100.0,"recommended_duration":20,
       "tags":["arrays","hashing"],"skills":["Problem Solving","Data Structures"],
       "problem_statement":"Return indices of two numbers adding to a target."},
      {"id":"q2","unique_id":"lru-cache","type":"code","name":"LRU Cache","status":"published",
       "languages":["python","cpp"],"max_score":150.0,"recommended_duration":35,"tags":["design"]},
      {"id":"q3","unique_id":"sql-joins","type":"mcq","name":"SQL Joins","status":"published",
       "max_score":50.0,"recommended_duration":10,"tags":["sql"]}
    ],"next":null}
    """#

    /// The single-question read: the whole question resource plus the MCQ options, the
    /// (sensitive) correct answer, and the internal notes. `answer` is the documented
    /// **one-based option index**, not the option's text.
    static let questionDetail = #"""
    {"id":"q3","unique_id":"sql-joins","type":"mcq","name":"SQL Joins","status":"published",
     "owner":"u1","created_at":"2026-04-02T09:00:00Z",
     "max_score":50.0,"recommended_duration":10,"tags":["sql"],
     "problem_statement":"Which join keeps unmatched rows from the left table?",
     "options":["INNER JOIN","LEFT JOIN","RIGHT JOIN","FULL OUTER JOIN"],
     "answer":2,"internal_notes":"Swap in a CROSS JOIN distractor next revision."}
    """#

    // MARK: - Interviews

    static let interviews = #"""
    {"data":[
      {"id":"i1","status":"completed","url":"https://www.hackerrank.com/x/interviews/i1",
       "title":"Senior Backend — Pairing","created_at":"2026-05-05T13:00:00Z",
       "from":"2026-05-05T13:00:00Z","to":"2026-05-05T14:00:00Z",
       "ended_at":"2026-05-05T14:00:00Z","thumbs_up":1,"feedback":"Strong system design.",
       "report_url":"https://www.hackerrank.com/x/interviews/i1/report"},
      {"id":"i2","status":"scheduled","url":"https://www.hackerrank.com/x/interviews/i2",
       "from":"2026-05-12T16:00:00Z","to":"2026-05-12T17:00:00Z",
       "title":"Frontend — Live Coding","created_at":"2026-05-12T16:00:00Z"}
    ],"next":null}
    """#

    /// The richer single-interview read: the additive detail fields (scheduled window,
    /// interviewers, owner, candidate, links) over the list shape.
    static let interviewDetail = #"""
    {"id":"i1","status":"completed","url":"https://www.hackerrank.com/x/interviews/i1",
     "title":"Senior Backend — Pairing","created_at":"2026-05-05T13:00:00Z",
     "ended_at":"2026-05-05T14:00:00Z","thumbs_up":1,"feedback":"Strong system design.",
     "report_url":"https://www.hackerrank.com/x/interviews/i1/report",
     "from":"2026-05-05T13:00:00Z","to":"2026-05-05T14:00:00Z",
     "resume_url":"https://www.hackerrank.com/x/interviews/i1/resume",
     "result_url":"https://www.hackerrank.com/x/interviews/i1/result",
     "user":4821,
     "candidate":{"firstname":"Ada","lastname":"Lovelace","email":"ada@example.com"},
     "interviewers":[{"firstname":"Ian","lastname":"Interviewer","email":"ian@example.com"},
                     {"firstname":"Rhea","lastname":"Recruiter","email":"rhea@example.com"}]}
    """#

    /// The conversation transcript. Deterministic demo dialogue — no real personal data;
    /// the pad's source code is not part of the transcript. Timestamps are epoch
    /// **milliseconds**, the 13-digit values the API actually returns.
    static let interviewTranscript = #"""
    {"messages":[
      {"messageId":"m1","author":"Ian Interviewer","email":"ian@example.com","candidate":false,
       "timestamp":1746450000000,"text":"Welcome! Let's start with a brief warm-up question."},
      {"messageId":"m2","author":"Ada Lovelace","email":"ada@example.com","candidate":true,
       "timestamp":1746450060000,"text":"Sounds good — I'm ready when you are."},
      {"messageId":"m3","author":"Ian Interviewer","email":"ian@example.com","candidate":false,
       "timestamp":1746450120000,"text":"Great. Can you walk me through your approach?"}
    ]}
    """#

    // MARK: - Templates

    static let interviewTemplates = #"""
    {"data":[
      {"id":101,"name":"Backend Pairing","created_at":"2026-04-10T09:00:00Z","status":1,"user":4821,
       "roles":["8b1o41tbpiq"],"team_share":1,"questions":["q1","q2"],"scorecard":98765,
       "import_template":true,"editor_access":true},
      {"id":102,"name":"Frontend Pairing","created_at":"2026-04-11T09:00:00Z","status":1,"user":4821,
       "roles":[],"team_share":0,"questions":[],"import_template":true,"editor_access":false}
    ],"next":null}
    """#

    static let interviewTemplate = #"""
    {"id":101,"name":"Backend Pairing","created_at":"2026-04-10T09:00:00Z","status":1,"user":4821,
     "roles":["8b1o41tbpiq"],"team_share":1,"questions":["q1","q2"],"scorecard":98765,
     "import_template":true,"editor_access":true}
    """#

    static let inviteTemplates = #"""
    {"data":[
      {"id":"tpl-1","name":"Default Invite","subject":"Your HackerRank invite","content":"<p>Please complete the assessment.</p>","default":true,"created_at":"2026-03-01T09:00:00Z","updated_at":"2026-04-01T09:00:00Z","user":"u1"},
      {"id":"tpl-2","name":"Reminder","subject":"Reminder","content":"<p>A reminder.</p>","default":false,"created_at":"2026-03-05T09:00:00Z","updated_at":"2026-03-05T09:00:00Z","user":"u1"}
    ],"next":null}
    """#

    static let inviteTemplate = #"""
    {"id":"tpl-1","name":"Default Invite","subject":"Your HackerRank invite","content":"<p>Please complete the assessment.</p>","default":true,"created_at":"2026-03-01T09:00:00Z","updated_at":"2026-04-01T09:00:00Z","user":"u1"}
    """#

    // MARK: - SCIM provisioning

    static let scimUsers = #"""
    {"Resources":[
      {"id":"scim-u1","userName":"rhea@example.com","active":true,"role":"recruiter",
       "team_admin":true,"company_admin":true,
       "name":{"givenName":"Rhea","familyName":"Recruiter"},
       "emails":[{"value":"rhea@example.com","primary":true}],"schemas":[]}
    ],"totalResults":1,"startIndex":0,"itemsPerPage":100}
    """#

    static let scimUser = #"""
    {"id":"scim-u1","userName":"rhea@example.com","active":true,"role":"recruiter",
     "team_admin":true,"company_admin":true,
     "name":{"givenName":"Rhea","familyName":"Recruiter"},
     "emails":[{"value":"rhea@example.com","primary":true}],"schemas":[]}
    """#

    static let scimGroups = #"""
    {"Resources":[
      {"id":"scim-g1","displayName":"Backend Hiring","members":[{"value":"scim-u1"}],"schemas":[]}
    ],"totalResults":1,"startIndex":0,"itemsPerPage":100}
    """#

    static let scimGroup = #"""
    {"id":"scim-g1","displayName":"Backend Hiring","members":[{"value":"scim-u1"}],"schemas":[]}
    """#

    // MARK: - Users & teams

    static let users = #"""
    {"data":[
      {"id":"u1","email":"rhea@example.com","firstname":"Rhea","lastname":"Recruiter",
       "country":"GB","phone":"+44 20 7946 0000","timezone":"Europe/London",
       "role":"recruiter","status":"active","teams":["tm1","tm2"],
       "activated":true,"company_admin":true,"team_admin":true,
       "questions_permission":2,"tests_permission":2,"interviews_permission":1,
       "candidates_permission":2,"shared_questions_permission":1,"shared_tests_permission":1,
       "shared_interviews_permission":0,"shared_candidates_permission":1,
       "last_activity_time":"2026-06-20T08:30:00Z"},
      {"id":"u2","email":"ian@example.com","firstname":"Ian","lastname":"Interviewer",
       "country":"DE","role":"interviewer","status":"active","teams":["tm1"],
       "activated":true,"company_admin":false,"team_admin":false},
      {"id":"u3","email":"pat@example.com","firstname":"Pat","lastname":"Pending",
       "country":"US","role":"recruiter","status":"invited","teams":[],
       "activated":false,"company_admin":false,"team_admin":false},
      {"id":"u4","email":"noname@example.com"}
    ],"next":null}
    """#

    /// The single-user object returned by `/users/me`: the demo account's own identity,
    /// in the same shape as a People-list entry but not wrapped in a paged envelope.
    static let currentUser = #"""
    {"id":"u-me","email":"demo@example.com","firstname":"Demo","lastname":"Owner",
     "country":"GB","role":"admin","status":"active","company_admin":true}
    """#

    /// The single-user object returned by `/users/{id}` in the demo.
    static let singleUser = #"""
    {"id":"u1","email":"rhea@example.com","firstname":"Rhea","lastname":"Recruiter",
     "country":"GB","phone":"+44 20 7946 0000","timezone":"Europe/London",
     "role":"recruiter","status":"active","teams":["tm1","tm2"],
     "activated":true,"company_admin":true,"team_admin":true,
     "questions_permission":2,"tests_permission":2,"interviews_permission":1,
     "candidates_permission":2,"shared_questions_permission":1,"shared_tests_permission":1,
     "shared_interviews_permission":0,"shared_candidates_permission":1}
    """#

    static let teams = #"""
    {"data":[
      {"id":"tm1","name":"Backend Hiring","owner":"u1","created_at":"2026-04-01T09:00:00Z",
       "recruiter_count":3,"developer_count":12,"interviewer_count":2,"recruiter_cap":5,"developer_cap":20,
       "invite_as":"Example Recruiting",
       "locations":["London","Berlin"],"departments":["Engineering","Platform"]},
      {"id":"tm2","name":"Data Science","owner":"u1","created_at":"2026-04-15T09:00:00Z",
       "recruiter_count":1,"developer_count":5,"locations":["Remote"]},
      {"id":"tm3","name":"Unstaffed Team"}
    ],"next":null}
    """#

    /// The single-team object returned by `/teams/{id}` in the demo.
    static let singleTeam = #"""
    {"id":"tm1","name":"Backend Hiring","owner":"u1","created_at":"2026-04-01T09:00:00Z",
     "recruiter_count":3,"developer_count":12,"interviewer_count":2,"recruiter_cap":5,"developer_cap":20,
     "invite_as":"Example Recruiting",
     "locations":["London","Berlin"],"departments":["Engineering","Platform"]}
    """#

    /// The membership object returned by `/teams/{team_id}/users/{user_id}` in the demo:
    /// the two ids that make up the relationship, which is all the endpoint returns.
    static let teamMembership = #"""
    {"team":"tm1","user":"u1"}
    """#

    // MARK: - Search

    /// Users the demo "user search" matches over. A small, sanitized set distinct enough
    /// that a query visibly narrows it.
    static let userSearch = #"""
    {"data":[
      {"id":"u1","email":"rhea@example.com","firstname":"Rhea","lastname":"Recruiter",
       "country":"GB","role":"recruiter","status":"active"},
      {"id":"u2","email":"ian@example.com","firstname":"Ian","lastname":"Interviewer",
       "country":"DE","role":"interviewer","status":"active"},
      {"id":"u3","email":"pat@example.com","firstname":"Pat","lastname":"Pending",
       "country":"US","role":"recruiter","status":"invited"}
    ],"next":null}
    """#

    /// The organisation-wide candidate search results. This endpoint answers with
    /// `CandidateSearchResult` rows — a person plus their accessible attempts — keyed by
    /// `uuid`, not with the per-test candidate records the other searches return.
    static let organizationCandidateSearch = #"""
    {"data":[
      {"uuid":"cand-ada","name":"Ada Lovelace","email":"ada@example.com",
       "created_at":"2026-04-20T09:00:00Z","updated_at":"2026-05-02T11:15:00Z",
       "attempts":[{"attempt_id":"c1","test_id":"t1","score":92.0,"percentage_score":92.0,
                    "report_url":"https://www.hackerrank.com/x/candidates/c1/report",
                    "attempt_starttime":"2026-05-02T10:00:00Z","attempt_endtime":"2026-05-02T11:15:00Z"}]},
      {"uuid":"cand-grace","name":"Grace Hopper","email":"grace@example.com",
       "created_at":"2026-04-22T09:00:00Z","updated_at":"2026-05-04T09:30:00Z",
       "attempts":[{"attempt_id":"c3","test_id":"t1","score":58.0,"percentage_score":58.0,
                    "report_url":"https://www.hackerrank.com/x/candidates/c3/report",
                    "attempt_starttime":"2026-05-04T08:30:00Z"}]}
    ],"next":null}
    """#

    /// Candidates the demo per-test "candidate search" matches over.
    static let candidateSearch = #"""
    {"data":[
      {"id":"c1","email":"ada@example.com","full_name":"Ada Lovelace","score":92.0,
       "percentage_score":92.0,"integrity_status":"clean","status":7,"ats_state":2,
       "attempt_starttime":"2026-05-02T10:00:00Z","attempt_endtime":"2026-05-02T11:15:00Z"},
      {"id":"c3","email":"grace@example.com","full_name":"Grace Hopper","score":58.0,
       "percentage_score":58.0,"integrity_status":"review","plagiarism_status":true,
       "status":7,"ats_state":22,"attempt_starttime":"2026-05-04T08:30:00Z"}
    ],"next":null}
    """#

    // MARK: - Audit log

    /// A deterministic change history with varied actions, source types, and a numeric
    /// `source_id` to exercise the model's string-or-number decoding.
    static let auditLog = #"""
    {"data":[
      {"source_id":"t1","source_type":"test","action":"update",
       "user":{"firstname":"Rhea","lastname":"Recruiter","email":"rhea@example.com"},
       "modified_fields":["name","cutoff_score"],
       "modified_values":{"name":"Backend Engineer Screen","cutoff_score":70},
       "ip_address":"203.0.113.7",
       "created_at":"2026-06-20T09:15:00Z"},
      {"source_id":"u3","source_type":"user","action":"create",
       "user":{"firstname":"Rhea","lastname":"Recruiter","email":"rhea@example.com"},
       "modified_fields":["email","role"],
       "modified_values":{"email":"pat@example.com","role":"recruiter"},
       "ip_address":"203.0.113.7",
       "created_at":"2026-06-19T16:42:00Z"},
      {"source_id":1024,"source_type":"interview","action":"delete",
       "user":"ian@example.com","modified_fields":[],"ip_address":"198.51.100.22",
       "created_at":"2026-06-18T11:05:00Z"}
    ],"next":null}
    """#
}

// swiftlint:enable line_length
