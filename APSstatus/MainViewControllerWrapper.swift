import SwiftUI

struct MainViewControllerWrapper: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let mainVC = MainViewController()
        
        // Wrap in UINavigationController
        let navController = UINavigationController(rootViewController: mainVC)
        
        // Optional: make the navigation bar consistent with system style
        navController.navigationBar.prefersLargeTitles = false
        navController.navigationBar.isTranslucent = true
        
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // Nothing to update dynamically
    }
}
