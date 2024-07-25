import SwiftUI
import GoogleMobileAds

struct BannerView: UIViewControllerRepresentable {
    @State private var viewWidth: CGFloat = .zero
    private let bannerView = GADBannerView(adSize: GADAdSizeBanner) // Initialize with a default ad size
    private let adUnitID = "ca-app-pub-8123911361564753/2857006000"
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let bannerViewController = BannerViewController()
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = bannerViewController
        bannerViewController.view.addSubview(bannerView)
        bannerViewController.delegate = context.coordinator
        bannerView.delegate = context.coordinator
        return bannerViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        if viewWidth != .zero {
            let newAdSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(viewWidth)
            if !CGSizeEqualToSize(bannerView.adSize.size, newAdSize.size) {
                bannerView.adSize = newAdSize
                bannerView.load(GADRequest())
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, BannerViewControllerWidthDelegate, GADBannerViewDelegate {
        let parent: BannerView
        
        init(_ parent: BannerView) {
            self.parent = parent
        }
        
        func bannerViewController(_ bannerViewController: BannerViewController, didUpdate width: CGFloat) {
            parent.viewWidth = width
            let newAdSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
            if !CGSizeEqualToSize(parent.bannerView.adSize.size, newAdSize.size) {
                parent.bannerView.adSize = newAdSize
                parent.bannerView.load(GADRequest())
            }
        }
        
        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            print("Banner loaded successfully")
        }
        
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("Failed to load banner ad: \(error.localizedDescription)")
        }
    }
}

struct BannerView_Previews: PreviewProvider {
    static var previews: some View {
        BannerView()
    }
}
