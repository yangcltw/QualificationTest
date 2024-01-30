import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
      let root = VideoSourceSelectionViewController()
      let navigationController = UINavigationController(rootViewController: root)
      self.window?.rootViewController = navigationController
      self.window?.makeKeyAndVisible()
    return true
  }
}
