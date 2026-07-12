//
//  MockServer+Fixtures.swift
//  HackerRankKit
//
//  The fake API's canned fixture data: deterministic, sanitized demo records for the
//  HackerRank for Work endpoints. No real personal data.
//

import Foundation

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

    static let testsPage1 = #"""
    {"data":[
      {"id":"t1","unique_id":"backend-screen","name":"Backend Engineer Screen","state":"active",
       "start_time":"2026-05-01T09:00:00Z","end_time":"2026-06-01T09:00:00Z","duration":90,
       "languages":["python","go","java"],"cutoff_score":70,"tags":["backend","screening"],
       "library":"HackerRank","role":"Backend Engineer","skills":["APIs","Data Structures"],"type":"Screen",
       "enable_proctoring":true,"instructions":"Solve all questions within the time limit.","questions":["q1","q2"],
       "sections":[{"uuid":"s1","name":"Coding","questions":2,"duration":60},
                   {"uuid":"s2","name":"Multiple Choice","questions":5,"duration":30}]},
      {"id":"t2","unique_id":"frontend-takehome","name":"Frontend Take-Home","state":"active",
       "start_time":"2026-05-10T09:00:00Z","duration":120,"languages":["javascript","typescript"],
       "cutoff_score":65,"tags":["frontend"],"library":"HackerRank","role":"Frontend Engineer",
       "skills":["React","Accessibility"],"type":"Take Home"},
      {"id":"t3","unique_id":"ds-quiz","name":"Data Structures Quiz","state":"archived",
       "duration":45,"languages":["cpp"],"cutoff_score":80,"tags":["algorithms","mcq"],
       "library":"HackerRank","role":"General Engineering","skills":["Algorithms"],"type":"Quiz"}
    ],"next":"https://www.hackerrank.com/x/api/v3/tests?limit=3&offset=3"}
    """#

    static let testsPage2 = #"""
    {"data":[
      {"id":"t4","unique_id":"sre-screen","name":"SRE On-Call Screen","state":"active",
       "start_time":"2026-05-15T09:00:00Z","duration":75,"languages":["python","bash"],
       "cutoff_score":72,"tags":["sre","backend"],"library":"HackerRank","role":"SRE",
       "skills":["Incident Response","Shell"],"type":"Screen","draft":true},
      {"id":"t5","unique_id":"ml-fundamentals","name":"ML Fundamentals","state":"active",
       "duration":60,"languages":["python"],"cutoff_score":68,"tags":["ml"],"library":"HackerRank",
       "role":"Machine Learning Engineer","skills":["Machine Learning","Python"],"type":"Screen","locked":true}
    ],"next":null}
    """#

    /// The richer single-test read: candidate login links, the (sensitive) shared access
    /// password, and MCQ scoring over the list shape.
    static let testDetail = #"""
    {"id":"t1","unique_id":"backend-screen","name":"Backend Engineer Screen","state":"active",
     "duration":90,"languages":["python","go","java"],"cutoff_score":70,
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
    /// `{"data":[...]}` envelope used by `/candidates`.
    static let candidateDetail = #"""
    {"id":"c1","email":"ada@example.com","full_name":"Ada Lovelace","score":92.0,
     "percentage_score":92.0,"integrity_status":"clean","plagiarism_status":false,
     "status":7,"ats_state":2,
     "report_url":"https://www.hackerrank.com/x/candidates/c1/report",
     "pdf_url":"https://www.hackerrank.com/x/candidates/c1/report.pdf",
     "attempt_starttime":"2026-05-02T10:00:00Z","attempt_endtime":"2026-05-02T11:15:00Z",
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

    /// The richer single-question read: MCQ options, the (sensitive) correct answer, and
    /// internal notes over the list shape.
    static let questionDetail = #"""
    {"id":"q3","unique_id":"sql-joins","type":"mcq","name":"SQL Joins","status":"published",
     "max_score":50.0,"recommended_duration":10,"tags":["sql"],
     "options":["INNER JOIN","LEFT JOIN","RIGHT JOIN","FULL OUTER JOIN"],
     "answer":"INNER JOIN","internal_notes":"Swap in a CROSS JOIN distractor next revision."}
    """#

    // MARK: - Interviews

    static let interviews = #"""
    {"data":[
      {"id":"i1","status":"completed","url":"https://www.hackerrank.com/x/interviews/i1",
       "title":"Senior Backend — Pairing","created_at":"2026-05-05T13:00:00Z",
       "ended_at":"2026-05-05T14:00:00Z","thumbs_up":1,"feedback":"Strong system design.",
       "report_url":"https://www.hackerrank.com/x/interviews/i1/report"},
      {"id":"i2","status":"scheduled","url":"https://www.hackerrank.com/x/interviews/i2",
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
     "user":{"firstname":"Rhea","lastname":"Recruiter","email":"rhea@example.com"},
     "candidate":{"firstname":"Ada","lastname":"Lovelace","email":"ada@example.com"},
     "interviewers":[{"firstname":"Ian","lastname":"Interviewer","email":"ian@example.com"},
                     {"firstname":"Rhea","lastname":"Recruiter","email":"rhea@example.com"}]}
    """#

    /// The conversation transcript. Deterministic demo dialogue — no real personal data;
    /// the pad's source code is not part of the transcript.
    static let interviewTranscript = #"""
    {"messages":[
      {"messageId":"m1","author":"Ian Interviewer","email":"ian@example.com","candidate":false,
       "timestamp":1746450000,"text":"Welcome! Let's start with a brief warm-up question."},
      {"messageId":"m2","author":"Ada Lovelace","email":"ada@example.com","candidate":true,
       "timestamp":1746450060,"text":"Sounds good — I'm ready when you are."},
      {"messageId":"m3","author":"Ian Interviewer","email":"ian@example.com","candidate":false,
       "timestamp":1746450120,"text":"Great. Can you walk me through your approach?"}
    ]}
    """#

    // MARK: - Templates

    static let interviewTemplates = #"""
    {"data":[
      {"id":101,"name":"Backend Pairing","title":"Backend Pairing","description":"Live backend interview"},
      {"id":102,"name":"Frontend Pairing","title":"Frontend Pairing"}
    ],"next":null}
    """#

    static let interviewTemplate = #"""
    {"id":101,"name":"Backend Pairing","title":"Backend Pairing","description":"Live backend interview"}
    """#

    static let inviteTemplates = #"""
    {"data":[
      {"id":"tpl-1","name":"Default Invite","subject":"Your HackerRank invite","body":"Please complete the assessment.","access":"company"},
      {"id":"tpl-2","name":"Reminder","subject":"Reminder","access":"private"}
    ],"next":null}
    """#

    static let inviteTemplate = #"""
    {"id":"tpl-1","name":"Default Invite","subject":"Your HackerRank invite","body":"Please complete the assessment.","access":"company"}
    """#

    // MARK: - Users & teams

    static let users = #"""
    {"data":[
      {"id":"u1","email":"rhea@example.com","firstname":"Rhea","lastname":"Recruiter",
       "country":"GB","role":"recruiter","status":"active","teams":["tm1","tm2"],
       "activated":true,"company_admin":true,"team_admin":true,
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
     "country":"GB","role":"recruiter","status":"active","teams":["tm1","tm2"],
     "activated":true,"company_admin":true,"team_admin":true}
    """#

    static let teams = #"""
    {"data":[
      {"id":"tm1","name":"Backend Hiring","owner":"u1","created_at":"2026-04-01T09:00:00Z",
       "recruiter_count":3,"developer_count":12,"interviewer_count":8,
       "locations":["London","Berlin"],"departments":["Engineering","Platform"]},
      {"id":"tm2","name":"Data Science","owner":"u1","created_at":"2026-04-15T09:00:00Z",
       "recruiter_count":1,"developer_count":5,"locations":["Remote"]},
      {"id":"tm3","name":"Unstaffed Team"}
    ],"next":null}
    """#

    /// The single-team object returned by `/teams/{id}` in the demo.
    static let singleTeam = #"""
    {"id":"tm1","name":"Backend Hiring","owner":"u1","created_at":"2026-04-01T09:00:00Z",
     "recruiter_count":3,"developer_count":12,"interviewer_count":8,
     "locations":["London","Berlin"],"departments":["Engineering","Platform"]}
    """#

    /// The membership object returned by `/teams/{team_id}/users/{user_id}` in the demo.
    static let teamMembership = #"""
    {"id":"u1","email":"rhea@example.com","role":"recruiter","team_id":"tm1"}
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

    /// Candidates the demo "candidate search" matches over.
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
       "modified_fields":["name","cutoff_score"],"ip_address":"203.0.113.7",
       "created_at":"2026-06-20T09:15:00Z"},
      {"source_id":"u3","source_type":"user","action":"create",
       "user":{"firstname":"Rhea","lastname":"Recruiter","email":"rhea@example.com"},
       "modified_fields":["email","role"],"ip_address":"203.0.113.7",
       "created_at":"2026-06-19T16:42:00Z"},
      {"source_id":1024,"source_type":"interview","action":"delete",
       "user":"ian@example.com","modified_fields":[],"ip_address":"198.51.100.22",
       "created_at":"2026-06-18T11:05:00Z"}
    ],"next":null}
    """#
}
