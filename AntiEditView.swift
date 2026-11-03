import UIKit

@objc(AntiEditViewerController)
public class AntiEditViewerController: UIViewController {
    var imageUrlString: String = ""
    
    @objc(presentFrom:imageUrl:)
    public static func present(from vc: UIViewController, imageUrl: String) {
        let viewer = AntiEditViewerController()
        viewer.imageUrlString = imageUrl
        viewer.modalPresentationStyle = .fullScreen
        vc.present(viewer, animated: true, completion: nil)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.black
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.frame = self.view.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(imageView)
        
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("关闭", for: .normal)
        closeButton.frame = CGRect(x: 20, y: 50, width: 60, height: 40)
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        self.view.addSubview(closeButton)
        
        if imageUrlString.hasPrefix("http") {
            if let url = URL(string: imageUrlString), let data = try? Data(contentsOf: url) {
                imageView.image = UIImage(data: data)
            }
        } else if imageUrlString.hasPrefix("file://") {
            let path = imageUrlString.replacingOccurrences(of: "file://", with: "")
            imageView.image = UIImage(contentsOfFile: path)
        }
    }
    
    @objc func close() {
        self.dismiss(animated: true, completion: nil)
    }
}
