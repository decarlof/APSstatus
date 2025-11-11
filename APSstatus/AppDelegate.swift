import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    // For iOS 13+ SceneDelegate is used; include basic support for older iOS
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Basic window setup (for projects not using SceneDelegate)
        if #available(iOS 13.0, *) {
            // SceneDelegate will handle window
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
            let nav = UINavigationController(rootViewController: MainViewController())
            window?.rootViewController = nav
            window?.makeKeyAndVisible()
        }
        return true
    }
}
