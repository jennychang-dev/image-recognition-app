import Foundation
import Alamofire

public enum ImaggaRouter: URLRequestConvertible {

///////////////////////////////////////////////////////////////////////////////////////
//  DECLARE CONSTANTS TO HOLD THE IMAGGA BASE URL AND MY AUTHENTICATION TOKEN
///////////////////////////////////////////////////////////////////////////////////////
  
  enum Constants {
    static let baseURLPath = "http://api.imagga.com/v1"
    static let authenticationToken = "Basic YWNjXzhiN2FkZGU4Mjk0OTgxNDpjYjc1ZjBmNTI2NTVmNzVhNWI0YzFhMzQwODUxMGNiYQ=="
  }

///////////////////////////////////////////////////////////////////////////////////////
//  DECLARE THE ENUM CASES, EACH CASE RESPONDS TO AN API ENDPOINT
///////////////////////////////////////////////////////////////////////////////////////
  
  case content
  case tags(String)
  case colors(String)
  
///////////////////////////////////////////////////////////////////////////////////////
//  RETURN THE HTTP METHOD FOR EACH API ENDPOINT
///////////////////////////////////////////////////////////////////////////////////////
  
  var method: HTTPMethod {
    switch self {
    case .content:
      return .post
    case .tags, .colors:
      return .get
    }
  }
  
///////////////////////////////////////////////////////////////////////////////////////
//  RETURN THE PATH FOR EACH API ENDPOINT
///////////////////////////////////////////////////////////////////////////////////////
  
  var path: String {
    switch self {
      case .content:
        return "/content"
      case .tags:
        return "/tagging"
      case .colors:
        return "/colors"
    }
  }
  
///////////////////////////////////////////////////////////////////////////////////////
//  RETURN THE PARAMETERS FOR EACH API ENDPOINT
///////////////////////////////////////////////////////////////////////////////////////
  
  var parameters: [String: Any] {
    switch self {
    case .tags(let contentID):
      return ["content": contentID]
    case .colors(let contentID):
      return ["content": contentID, "extract_object_colors": 0]
    default:
      return [:]
    }
  }
  
///////////////////////////////////////////////////////////////////////////////////////
//  USE ALL THE ABOVE COMPONENTS TO CREATE A URL REQUEST
///////////////////////////////////////////////////////////////////////////////////////
  
  public func asURLRequest() throws -> URLRequest {
    let url = try Constants.baseURLPath.asURL()
    
    var request = URLRequest(url: url.appendingPathComponent(path))
    request.httpMethod = method.rawValue
    request.setValue(Constants.authenticationToken, forHTTPHeaderField: "Authorization")
    request.timeoutInterval = TimeInterval(10 * 1000)
    
    return try URLEncoding.default.encode(request, with: parameters)
  }
  
}
