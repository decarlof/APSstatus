import UIKit
import SafariServices

class MainViewController: UIViewController {

    var preferences: UserDefaults = .standard

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "APSStatus"
        setupNavigationBar()
        setupMainUI()
    }

    func setupNavigationBar() {
        let aboutItem = UIBarButtonItem(title: "About", style: .plain, target: self, action: #selector(showAbout))
        let settingsItem = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(openSettings))
        navigationItem.rightBarButtonItems = [aboutItem, settingsItem]
    }

    func setupMainUI() {
        let label = UILabel()
        label.text = "APSStatus (converted)"
        label.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let message = "This is version \(version) of APSStatus, originally by Michael Borland..."
        let ac = UIAlertController(title: "About APSStatus", message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Dismiss", style: .default))
        present(ac, animated: true)
    }

    @objc func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
