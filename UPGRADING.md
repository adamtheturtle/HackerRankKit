# Upgrading HackerRankKit

Breaking changes by release, with the before/after for each. Releases not listed here
were additive.

## 0.7.x → 0.8.0

0.8.0 rebuilt the package's wire contract against HackerRank's published schema
(<https://www.hackerrank.com/apidoc>). The old contract was wrong in enough places that
correcting it moved most of the public surface, so this upgrade is large — but almost
every change is one the compiler will point at.

Read [**Changes with no compiler error**](#changes-with-no-compiler-error) last and
carefully: those are the ones that alter behaviour while the code still builds.

### Methods that gained required parameters

The API rejects a create that omits these, so they are no longer optional. In 0.7.x the
minimal call compiled and then failed against the live server.

```swift
// Before
try await client.createTest(name: "Phone screen")
// After — `TestsCreate` requires all four
try await client.createTest(
    name: "Phone screen", duration: 60, roleIDs: ["backend-engineer"], experience: ["Senior"]
)

// Before
try await client.createQuestion(name: "Two Sum", type: "code")
// After — `QuestionCreate` requires the statement and the duration
try await client.createQuestion(
    name: "Two Sum", type: "code", problemStatement: "Return two indices.", recommendedDuration: 20
)

// Before — every argument optional
try await client.createUser(email: "ada@example.com")
// After — a blank value or an empty team list now throws before any request is made
try await client.createUser(
    email: "ada@example.com", firstName: "Ada", role: "recruiter", teamIDs: ["tm1"]
)

// Before
try await client.createInterviewTemplate(options: .init(name: "Backend Pairing"))
// After
try await client.createInterviewTemplate(name: "Backend Pairing")
```

### Methods that now return `Void`

These four endpoints answer `204 No Content`. Decoding a record from an empty body made
them report `HackerRankError.decode` *after* the mutation had already been applied.
Returning normally is now the whole result.

```swift
// Before
let archived = try await client.archiveTest(testID: "t1")   // threw on success
// After
try await client.archiveTest(testID: "t1")
```

Also `deleteTest(testID:)`, `lockUser(id:)`, and `removeTeamMember(teamID:userID:)`.
`UserWriteResult` had no remaining producer and is gone.

### Methods that were removed

| Removed | Why | Instead |
| --- | --- | --- |
| `deleteQuestion(questionID:)` | `DELETE /questions/{id}` does not exist; the path exposes only GET and PUT | Archive the question with `updateQuestion` |
| `addTeamMember(teamID:email:role:)` | `POST /teams/{id}/users` does not exist | `createUser(…, teamIDs:)`, or `addTeamMember(teamID:userID:license:)` for an existing user |

### Methods whose return type changed

```swift
// The organisation-wide search returns people and their attempts, not per-test records.
// In 0.7.x every match was silently discarded, so this search always looked empty.
let page: Page<CandidateSearchResult> = try await client.searchCandidates(query: "ada")
for result in page.items {
    print(result.name, result.attempts.map(\.testID))
}

// Generation returns the templates it produced, not a status acknowledgement.
let stubs: GeneratedCodeStubs = try await client.generateCodeStubs(questionID: "q1")
for template in stubs.templates { print(template.language, template.body ?? "") }

// The detail reads carry the whole resource, so they can replace a stale list row.
let question = try await client.question(id: "q1")
print(question.question.name)          // was unavailable
let interview = try await client.interview(id: "i1")
print(interview.interview.title)       // was unavailable
```

### Option types that lost properties

Each of these named a key the API does not define. Setting one looked like it configured
the request while the server ignored it.

- `TestWriteOptions`: `library`, `skills`, `type` removed; `role: String?` became
  `roleIDs: [String]?`.
- `QuestionWriteOptions`: `status`, `maxScore`, `clearsMaxScore`, `skills` removed;
  `internalNotes`, `mcqOptions`, and `answer` added.
- `InterviewTemplateWriteOptions` is replaced by `InterviewTemplateCreateOptions` and
  `InterviewTemplateUpdateOptions`, because the two endpoints accept different fields.
  `title`, `description`, `tags`, and `metadata` are gone; `roleID`, `teamShare`,
  `questionIDs` (create) and `scorecardID` (update) are new.
- `CodeStubGenerationOptions`: `returnType` → `functionReturn`, `languages` →
  `allowedLanguages`, and the `parameters: [CodeStubParameter]` array became a single
  `functionParams` signature string such as `"INTEGER param1 STRING param2"`.
  `CodeStubParameter` is gone.

`CandidateInviteOptions` was renamed almost field for field:

| Before | After |
| --- | --- |
| `validFrom` / `validUntil` | `inviteValidFrom` / `inviteValidTo` |
| `emailSubject` / `emailMessage` | `subject` / `message` |
| `templateID` | `template` |
| `finishURL` / `resultURL` | `testFinishURL` / `testResultURL` |
| `notifyResultUpdate` | `acceptResultUpdates` |
| `allowReattempt` | `forceReattempt` |
| `additionalTime: Int?` (minutes) | `accommodations: CandidateAccommodations?` (a percentage of the test duration) |
| `atsCandidateID` / `atsRequisitionID` | removed — those belong to the ATS endpoints |
| — | `webhookAuthentication`, which the API requires whenever a result URL is set |

### Model properties that changed

| Type | Before | After |
| --- | --- | --- |
| `Test` | `role: String?` | `roleIDs: [String]?` |
| `Team` | `interviewerCount` | removed — the schema has no such field. Use `recruiterCap` / `developerCap` / `inviteAs` |
| `InviteTemplate` | `body`, `access` | `content`; `access` removed (it is a list *query parameter*, not a field) |
| `InterviewTemplate` | `title`, `description` | removed; `createdAt`, `status`, `user`, `roles`, `teamShare`, `questions`, `scorecard`, `importTemplate`, `editorAccess` added |
| `TeamMembershipResult` | `id`, `email` | `team`, `user` |
| `InterviewTemplateWriteResult` | `id`, `status`, `message` | `message` |
| `QuestionDetail` | `answer: String?` | `answer: QuestionAnswer?` — a one-based option index, or several |
| `InterviewUpdateOptions` | `candidate: String?` | `candidate: InterviewCandidate?` |
| `QuestionCodeStub` | `init(language:code:)` | `init(language:body:head:tail:)` |
| `SCIMUserWriteRequest` | every field optional | `userName`, `name`, and `email` are required parameters |

Everything else is additive: `Test`, `TestCandidate`, `User`, `Team`, `Question`,
`Interview`, `InterviewTemplate`, `InviteTemplate`, and `AuditLogEntry` between them
gained over a hundred documented fields that used to be dropped.

### Changes with no compiler error

These alter behaviour while existing code still builds. They are the ones worth grepping
for.

- **Assessment windows now decode.** `Test.startTime` and `Test.endTime` read `starttime`
  and `endtime`; in 0.7.x they were always `nil`. Code that treated `nil` as "no window"
  will start seeing real dates.
- **Tests with sections are no longer dropped.** `sections` is documented as an object;
  declaring it as an array made a conforming response throw, and the lenient page decoder
  discarded the whole assessment. Lists may get longer.
- **Invite template content now decodes**, under `content` rather than the nonexistent
  `body`.
- **Transcript timestamps are milliseconds.** `InterviewMessage.timestamp` is 13-digit
  epoch ms, as the API returns. Anything doing
  `Date(timeIntervalSince1970: Double(timestamp))` was producing dates tens of thousands
  of years out; use `InterviewMessage.sentAt`.
- **`AuditLogEntry.id` changed shape.** It now includes every distinguishing field, so
  two changes to one resource in the same second no longer collide. Persisted ids from
  0.7.x will not match.
- **`candidate(testID:candidateID:)` sends `additional_fields` by default**, requesting
  `questions`, `attempt_events`, `comments`, and `ip_address`. The response is richer and
  heavier; pass `additionalFields: []` for the old, lighter read.
- **`test(id:)` sends `additional_fields` too.** Without it the server omits every field
  `TestDetail` models, so in 0.7.x that read could return nothing at all.
- **`HackerRankKitMock` now answers 404/405.** A route the API does not expose is no
  longer a canned success. Tests that leaned on the old catch-all will fail — which is
  the point.
