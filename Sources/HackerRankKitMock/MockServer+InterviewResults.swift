import Foundation

extension MockFixtures {
    nonisolated static let interviewArtifacts = #"""
    {
      "interview_id":"iv1",
      "transcript_url":{"state":"unavailable","location":null},
      "interviewer_notes":[{"note_id":1,"evaluator_id":2}],
      "questions":[{
        "tab_id":"1","question_sequence":1,"library_question_id":null,
        "qtype":"code","question_name":"Demo coding task",
        "artifacts":{"submitted_code_url":{"state":"unavailable","location":null}}
      }]
    }
    """#

    nonisolated static let interviewNotes = #"""
    {"notes":[{
      "note_id":1,"evaluator_id":2,"evaluator_name":"Demo Interviewer",
      "content":"Discussed testing and edge cases.","updated_at":"2026-11-07T10:00:00Z","editable":true
    }]}
    """#

    nonisolated static let updatedInterviewNote = #"""
    {"content":"Demo note saved","updated_at":"2026-11-07T10:01:00Z"}
    """#

    nonisolated static let auditCursorFirst = #"""
    {
      "data":[{"source_id":1,"source_type":"test","action":"update","user":"2"}],
      "page_total":1,"has_more":true,"next_cursor":"demo-audit-next","total":2
    }
    """#

    nonisolated static let auditCursorLast = #"""
    {
      "data":[{"source_id":2,"source_type":"question","action":"update","user":"2"}],
      "page_total":1,"has_more":false,"next_cursor":null
    }
    """#
}
