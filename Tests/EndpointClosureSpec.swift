import Foundation
import Nimble
import Quick
import Alamofire
@testable import Moya

final class EndpointClosureSpec: QuickSpec {

    override func spec() {
        var provider: MoyaProvider<HTTPBin>!
        var session: SessionMock!

        beforeEach {
            session = SessionMock()
            let endpointClosure: MoyaProvider<HTTPBin>.EndpointClosure = { target in
                let task: Task

                switch target.task {
                case let .uploadMultipart(multipartFormData):
                    let additional = Moya.MultipartFormData(provider: .data("test2".data(using: .utf8)!), name: "test2")
                    var newMultipartFormData = multipartFormData
                    newMultipartFormData.append(additional)
                    task = .uploadMultipart(newMultipartFormData)
                default:
                    task = target.task
                }

                return Endpoint(url: URL(target: target).absoluteString, sampleResponseClosure: {.networkResponse(200, target.sampleData)}, method: target.method, task: task, httpHeaderFields: target.headers)
            }
            provider = MoyaProvider<HTTPBin>(endpointClosure: endpointClosure, session: session)
        }

        it("appends additional multipart body in endpointClosure") {
            let multipartData1 = Moya.MultipartFormData(provider: .data("test1".data(using: .utf8)!), name: "test1")
            let multipartData2 = Moya.MultipartFormData(provider: .data("test2".data(using: .utf8)!), name: "test2")

            let providedMultipartData = [multipartData1]
            let sentMultipartData = [multipartData1, multipartData2]

            _ = provider.request(.uploadMultipart(providedMultipartData, nil)) { _ in }
            let stringData1 = String(data: try! session.uploadMultipartFormData!.encode(), encoding: .utf8)

            let requestMultipartFormData = RequestMultipartFormData()
            requestMultipartFormData.applyMoyaMultipartFormData(sentMultipartData)
            let stringData2 = String(data: try! requestMultipartFormData.encode(), encoding: .utf8)

            let formData1 = "data; name=\"test1\"\r\n\r\ntest1\r\n"
            let formData2 = "data; name=\"test2\"\r\n\r\ntest2\r\n"

            let splitString1 = stringData1?.split(separator: "-").map { String($0) }
            let splitString2 = stringData2?.split(separator: "-").map { String($0) }

            expect(splitString1).to(contain(formData1))
            expect(splitString1).to(contain(formData2))
            expect(splitString2).to(contain(formData1))
            expect(splitString2).to(contain(formData2))

        }
    }
}

final class SessionMock: Alamofire.Session {

    var uploadMultipartFormData: Alamofire.MultipartFormData?

    override func upload(multipartFormData: @escaping (Alamofire.MultipartFormData) -> Void,
        usingThreshold encodingMemoryThreshold: UInt64,
        with urlRequest: URLRequestConvertible,
        queue: DispatchQueue?,
        encodingCompletion: ((SessionManager.MultipartFormDataEncodingResult) -> Void)?) {
            
        let uploadMultipartFormData = Alamofire.MultipartFormData()
        multipartFormData(uploadMultipartFormData)
        self.uploadMultipartFormData = uploadMultipartFormData
        return super.upload(multipartFormData: multipartFormData, usingThreshold: encodingMemoryThreshold, fileManager: fileManager, with: request, interceptor: interceptor)
    }
}
