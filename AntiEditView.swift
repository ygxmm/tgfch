import UIKit

@objc(AntiEditViewerController)
public class AntiEditViewerController: UIViewController {
    var messageText: String = ""
    
    @objc(presentFrom:imageUrl:)
    public static func present(from vc: UIViewController, imageUrl: String) {
        let viewer = AntiEditViewerController()
        viewer.messageText = imageUrl
        viewer.modalPresentationStyle = .fullScreen
        vc.present(viewer, animated: true, completion: nil)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.black
        
        let textView = UITextView()
        textView.text = messageText
        textView.textColor = .green // 用绿色更显眼
        textView.backgroundColor = .clear
        textView.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.isEditable = false
        textView.frame = CGRect(x: 10, y: 100, width: self.view.bounds.width - 20, height: self.view.bounds.height - 150)
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(textView)
        
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("关闭", for: .normal)
        closeButton.frame = CGRect(x: 20, y: 50, width: 60, height: 40)
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        self.view.addSubview(closeButton)
    }
    
    @objc func close() {
        self.dismiss(animated: true, completion: nil)
    }
}
