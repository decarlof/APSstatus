import SafariServices
import SwiftUI  // add this

class MainViewController: UIViewController {

    var preferences: UserDefaults = .standard
    private var hostingController: UIHostingController<ContentView>?

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
        // Host your SwiftUI ContentView (which contains all pages)
        let swiftUIView = ContentView() // ensure ContentView includes your new SDDSAllParamsView pages
        let hosting = UIHostingController(rootView: swiftUIView)

        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hosting.didMove(toParent: self)
        self.hostingController = hosting
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
