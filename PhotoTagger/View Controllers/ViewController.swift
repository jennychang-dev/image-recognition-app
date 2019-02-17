import SwiftyJSON
import Alamofire

class ViewController: UIViewController {

  // MARK: - IBOutlets
  @IBOutlet var takePictureButton: UIButton!
  @IBOutlet var imageView: UIImageView!
  @IBOutlet var progressView: UIProgressView!
  @IBOutlet var activityIndicatorView: UIActivityIndicatorView!

  // MARK: - Properties
  private var tags: [String]?
  private var colors: [PhotoColor]?

  // MARK: - View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if !UIImagePickerController.isSourceTypeAvailable(.camera) {
      takePictureButton.setTitle("Select Photo", for: .normal)
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)

    imageView.image = nil
  }

  // MARK: - Navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

    if segue.identifier == "ShowResults",
      let controller = segue.destination as? TagsColorsViewController {
      controller.tags = tags
      controller.colors = colors
    }
  }

  // MARK: - IBActions
  @IBAction func takePicture(_ sender: UIButton) {
    let picker = UIImagePickerController()
    picker.delegate = self
    picker.allowsEditing = false

    if UIImagePickerController.isSourceTypeAvailable(.camera) {
      picker.sourceType = .camera
    } else {
      picker.sourceType = .photoLibrary
      picker.modalPresentationStyle = .fullScreen
    }

    present(picker, animated: true)
  }
}

// MARK: - UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
    guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
      print("Info did not have the required UIImage for the Original Image")
      dismiss(animated: true)
      return
    }

    imageView.image = image

///////////////////////////////////////////////////////////////////////////////////////
//  HIDE THE UPLOAD BUTTON AND SHOW THE PROGRESS VIEW AND ACTIVITY VIEW
///////////////////////////////////////////////////////////////////////////////////////
    
    takePictureButton.isHidden = true
    progressView.progress = 0.0
    progressView.isHidden = false
    activityIndicatorView.startAnimating()
    
    upload(image: image, progressCompletion: { [unowned self] percent in
      
///////////////////////////////////////////////////////////////////////////////////////
//  WHILE THE FILE UPLOADS, WE CALL THE PROGRESS HANDLER WITH AN UPDATED %
///////////////////////////////////////////////////////////////////////////////////////
      
      self.progressView.setProgress(percent, animated: true)},
        completion: { [unowned self] tags, colors in
          
///////////////////////////////////////////////////////////////////////////////////////
//  COMPLETION HANDLER EXECUTRES WHEN THE UPLOAD FINISHES --> SETS THE CONTORLS BACK TO THEIR ORIGINAL STATE
///////////////////////////////////////////////////////////////////////////////////////
          
          self.takePictureButton.isHidden = false
          self.progressView.isHidden = true
          self.activityIndicatorView.stopAnimating()
          
          self.tags = tags
          self.colors = colors
          
///////////////////////////////////////////////////////////////////////////////////////
//  ADVANCE TO RESULTS SCREEN WHEN THE UPLOAD COMPLETES, SUCCESSFULLY OR NOT
///////////////////////////////////////////////////////////////////////////////////////
          
          self.performSegue(withIdentifier: "ShowResults", sender: self)
          
    })
    
    dismiss(animated: true)
  }
}

extension ViewController {
  
///////////////////////////////////////////////////////////////////////////////////////
//  UPLOADING IMAGE
///////////////////////////////////////////////////////////////////////////////////////
  
  func upload(image: UIImage,
              progressCompletion: @escaping (_ percent: Float) -> Void,
              completion: @escaping (_ tags: [String]?, _ colors: [PhotoColor]?) -> Void) {
    
///////////////////////////////////////////////////////////////////////////////////////
//  WE NEED TO CONVERT THE IMAGE BEING UPLOADED TO A DATA INSTANCE
///////////////////////////////////////////////////////////////////////////////////////
    
    guard let imageData = UIImageJPEGRepresentation(image, 0.5) else {
      print("could not get JPEG representation of UIImage")
      return
    }
    
///////////////////////////////////////////////////////////////////////////////////////
//  CONVERT JPEG DATA BLOB (IMAGEDATA) INTO A MIME MULTIPART REQUEST TO SEND TO THE IMAGGA CONTENT ENDPOINT
///////////////////////////////////////////////////////////////////////////////////////
    
    Alamofire.upload(multipartFormData: { multipartFormData in
      multipartFormData.append(imageData,
                               withName: "imagefile",
                               fileName: "image.jpg",
                               mimeType: "image/jpeg")
    },
                     with: ImaggaRouter.content,
                     encodingCompletion: { encodingResult in
                      
///////////////////////////////////////////////////////////////////////////////////////
//  CALLS THE ALAMOFIRE FUNCTION AND PASSES IN A SMALL CALCULATION TO UPDATE THE PROGRESS BAR AS THE FILE UPLAODS
///////////////////////////////////////////////////////////////////////////////////////
            
                      switch encodingResult {
                      case .success(let upload, _, _):
                        upload.uploadProgress { progress in
                          progressCompletion(Float(progress.fractionCompleted))
                        }
                        upload.validate()
                        upload.responseJSON { response in
                          
///////////////////////////////////////////////////////////////////////////////////////
//  CHECK THAT THE UPLOAD WAS SUCCESSFUL AND THE RESULT HAS A VALUE, IF NOT PRINT ERROR
///////////////////////////////////////////////////////////////////////////////////////
                          guard response.result.isSuccess,
                            let value = response.result.value else {
                              print("error while uploading file: \(String(describing: response.result.error))")
                              completion(nil, nil)
                              return
                          }

///////////////////////////////////////////////////////////////////////////////////////
//  USING SWIFTYJSON, RETRIEVE THE FIRSTFILEID FROM THE RESPONSE
///////////////////////////////////////////////////////////////////////////////////////
                          
                          let firstFileId = JSON(value)["uploaded"][0]["id"].stringValue
                          print("content uploaded with ID: \(firstFileId)")
                          
                          downloadTags(contentID: firstFileId) { tags in
                            completion(tags, nil)
                            downloadColors(contentID: firstFileId) { colors in
                              completion(tags, colors)
                              
                            }
                          }
                        }
                        
///////////////////////////////////////////////////////////////////////////////////////
//  CALL THE COMPLETION HANDLER TO UPDATE THE UI
///////////////////////////////////////////////////////////////////////////////////////
                        
                      case .failure(let encodingError):
                        print(encodingError)
                      }
                      
    })
    
    func downloadTags(contentID: String, completion: @escaping ([String]?) -> Void) {
      
///////////////////////////////////////////////////////////////////////////////////////
//  PERFORM AN HTTP GET REQUEST AGAINST THE TAGGING ENDPOINT, SENDING THE URL PARAMETER WITH ID YOU RECEIVED AFTER YOUR UPLOADED
///////////////////////////////////////////////////////////////////////////////////////
      print("REQUESTING")
      Alamofire.request(ImaggaRouter.tags(contentID))
            
///////////////////////////////////////////////////////////////////////////////////////
//  CHECK IF RESPONSE WAS SUCCESSFUL, IF IT HAS NO VALUE THEN PRINT THE ERROR AND CALL THE COMPLETION HANDLER
///////////////////////////////////////////////////////////////////////////////////////
        
        .responseJSON { response in
          guard response.result.isSuccess,
            let value = response.result.value else {
              print("error while fetching tags: \(String(describing: response.result.error))")
              completion(nil)
              return
          }
          
///////////////////////////////////////////////////////////////////////////////////////
//  USING SWIFTYJSON, RETRIEVE THE RAW 'TAGS' ARRAY FROM THE RESPONSE, RETRIEVING THE VALUE ASSOCIATED WITH THE TAG KEY
///////////////////////////////////////////////////////////////////////////////////////
          
          let tags = JSON(value)["results"][0]["tags"].array?.map { json in
            json["tag"].stringValue
          }

///////////////////////////////////////////////////////////////////////////////////////
//  CALL THE COMPLETION HANDLER PASSING IN THE TAGS RECEIVED FROM THE SERVICE
///////////////////////////////////////////////////////////////////////////////////////
          
          completion(tags)
          
      }
    }
    
    func downloadColors(contentID: String, completion: @escaping ([PhotoColor]?) -> Void) {
      
///////////////////////////////////////////////////////////////////////////////////////
//  PERFORM AN HTTP GET REQUEST AGAINST THE COLORS ENDPOINT, SENDING THE URL PARAMETER CONTENT WITH THE ID
///////////////////////////////////////////////////////////////////////////////////////
      
      Alamofire.request(ImaggaRouter.colors(contentID))
        .responseJSON { response in

///////////////////////////////////////////////////////////////////////////////////////
//  CHECK THAT THE RESPONSE WAS SUCCESSFUL AND THE RESULT HAS A VALUE, IF NOT PRINT THE ERROR
///////////////////////////////////////////////////////////////////////////////////////
          
          guard response.result.isSuccess,
            let value = response.result.value else {
              print("Error while fetching colors: \(String(describing: response.result.error))")
              completion(nil)
              return
          }
          
///////////////////////////////////////////////////////////////////////////////////////
//  USING SWIFTYJSON RETRIEVE THE JSON, RETRIEVE THE IMAGE COLORS ARRAY FROM THE RESPONSE
///////////////////////////////////////////////////////////////////////////////////////
          
          let photoColors = JSON(value)["results"][0]["info"]["image_colors"].array?.map { json in
            PhotoColor(red: json["r"].intValue,
                       green: json["g"].intValue,
                       blue: json["b"].intValue,
                       colorName: json["closest_palette_color"].stringValue)
          }
          
///////////////////////////////////////////////////////////////////////////////////////
//  
///////////////////////////////////////////////////////////////////////////////////////
          
          completion(photoColors)
          
      }
    }
  }
}
