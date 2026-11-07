import Foundation
import HackerRankKit
import HackerRankKitMock
import Testing

struct TemplateIdentifiersTests {
    @Test func liveTemplateWireFormats() throws {
        let data = Data(#"{"id":"12345","questions":[42,17,99],"name":"Pairing"}"#.utf8)
        let template = try JSONDecoder().decode(InterviewTemplate.self, from: data)
        #expect(template.id == 12345)
        #expect(template.questions == ["42", "17", "99"])
        let page = try JSONDecoder().decode(HackerRankPage<InterviewTemplate>.self, from: Data(
            #"{"data":[{"id":"12345","questions":[42,17,99]}],"next":null}"#.utf8
        ))
        #expect(page.data.first?.id == 12345)
        #expect(page.data.first?.questions == ["42", "17", "99"])
    }

    @Test func missingAndEmptyMembershipRemainDistinct() throws {
        let empty = try JSONDecoder().decode(InterviewTemplate.self, from: Data(#"{"id":"1","questions":[]}"#.utf8))
        let absent = try JSONDecoder().decode(InterviewTemplate.self, from: Data(#"{"id":"2"}"#.utf8))
        #expect(empty.questions == [])
        #expect(absent.questions == nil)
        #expect(absent.id == 2)
    }

    @Test func templateAndQuestionMocksKeepRequestedIdentity() async throws {
        let client = HackerRankClient.mock()
        let frontend = try await client.interviewTemplate(id: 102)
        #expect(frontend.id == 102)
        #expect(frontend.name == "Frontend Pairing")
        #expect(frontend.questions == [])
        let backend = try await client.interviewTemplate(id: 101)
        #expect(backend.questions == ["1", "2"])
        let question = try await client.question(id: "1")
        #expect(question.question.id == "1")
        #expect(question.question.name == "Two Sum")
        let email = try await client.inviteTemplate(id: "tpl-2")
        #expect(email.id == "tpl-2")
        #expect(email.name == "Reminder")
    }
}
