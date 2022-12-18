//
//  ViewController.swift
//  TCMGuide
//
//  Created by Dobrinka Tabakova on 6/18/17.
//  Copyright © 2017 Dobrinka Tabakova. All rights reserved.
//

import UIKit
import PDFKit
import CryptoKit
import WidgetKit
import CloudKit

class ViewController: UIViewController, PDFDocumentDelegate, UISearchBarDelegate, UITextFieldDelegate, OutlineDelegate, UIPopoverPresentationControllerDelegate {
    
    func goTo(page: PDFPage) {
        self.pdfView.go(to: page)
    }
    
    
    var isPad = UIDevice.current.userInterfaceIdiom == .pad
    
    var pdfView: MyPDFView!
    var pdfDocument: PDFDocument!
    var selections: [PDFSelection] = []
    var mySearchBar: UISearchBar!
    var outlineViewController: OutlineTableViewController!
    var innerKey: String = "mctniveKmctniveK"
    var key: String = ""
    var seachInitialized: Bool = false
    var pdfLoaded: Bool = false
    var isStaging: Bool = false
    var loadingError: Bool = false
    var tapGestureRecognizer: UITapGestureRecognizer!
    var doubleTapGestureRecognizer: UITapGestureRecognizer!
    var loadingKeyFromCloudFailed: Bool = false
    var internetConnectionAvailable: Bool = true
    
    
    private var outlineButton = UIButton()
    private var outline: PDFOutline? = nil
    
    @IBOutlet weak var containerView: UIView!
    
    @IBOutlet weak var btnView: UIView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var searchResultLabel: UILabel!
    
    @IBOutlet weak var totalPageLabel: UILabel!
    @IBOutlet weak var nextBtn: UIButton!
    @IBOutlet weak var previousBtn: UIButton!
    
    var currentSelectionIndex = 0
    var currentPageIndex = 0
    var totalPageCount = 0
    
    @IBOutlet weak var currentPageTextBox: UITextField!
    
    var pdfThumbnailScrollView: UIScrollView!
    let thumbnailSize: Int = 100
    lazy var pdfThumbnailEndPadding: Int = { return 0 }()
    var thumbnailContainerView: UIView!
    
    
    var thumbnailView: PDFThumbnailView!
    var thumbnailViewShow = true;
    
    private func setupPdfView() {
        
        self.pdfView = MyPDFView()
        self.pdfView.autoScales = true
        self.pdfView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pdfView)
        
        self.pdfView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor).isActive = true
        self.pdfView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true
        self.pdfView.topAnchor.constraint(equalTo: self.searchBar.safeAreaLayoutGuide.bottomAnchor, constant: 50).isActive = true
        
        self.searchBar.backgroundImage = UIImage()
    }
    
    fileprivate func encryptBundle(_ pdfData: Data) {
        if(isStaging){
            do{
                let encrypted = try pdfData.aesEncrypted(_key: self.loadKey())
                let filePath = self.append(withPathComponent: "content1")
                try encrypted?.write(to: filePath!)
            }catch{
                print("encrypt content1 failed: " + error.localizedDescription)
            }
        }
  
        let uuid = (UIDevice.current.identifierForVendor?.uuidString.replacingOccurrences(of: "-", with: "").prefix(16))!
        let key = String(uuid) + self.innerKey
        do{
            let encrypted = try pdfData.aesEncrypted(_key: key)
            let filePath = self.append(withPathComponent: "content")
            try encrypted?.write(to: filePath!)
        }catch{
            print("encrypt content failed: " + error.localizedDescription)
        }
    }
    
    private func loadPdfDocument(){
        
        var pdfData: Data?
        if notInitialized() {
            pdfData = loadPdfDataFromBundle()
            if(pdfData != nil){
                encryptBundle(pdfData!)
            }
        } else {
            pdfData = loadPdfDataFromDirectory()
        }
       
        self.loadingError = false
        if(pdfData == nil){
            self.loadingError = true
            //如果是從Bundle取得PDF，會有ansync的問題，這時候viewDidAppear可能已經完成，所以呼叫alertRemoveApp,用來顯示移除並重新安裝App的警示訊息
            if(self.notInitialized()){
                //self.alertMessage(message: "程式初始發生錯誤，請移除並重新下載安裝。")
            }
        }else{
            let document =  PDFDocument(data: pdfData!)
            if(document == nil){
                self.loadingError = true
                //self.alertMessage(message: "程式初始發生錯誤，請移除並重新下載安裝。")
            }
            self.pdfDocument = document
            self.outline = self.pdfDocument.outlineRoot
            self.pdfDocument.delegate = self
        }
 
        self.pdfView.document = self.pdfDocument
        self.pdfView.displayDirection = .horizontal
        self.pdfView.pageBreakMargins = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        self.pdfView.usePageViewController(true)
        self.pdfView.autoScales = true
        self.pdfView.displaysPageBreaks = true
        
        //initialize page info
        self.currentPageIndex = 0
        self.totalPageCount = self.pdfView.document?.pageCount ?? 0
        self.totalPageLabel.text = "／ \(self.totalPageCount)"
        self.currentPageTextBox.text = "1"
        //先做一次search，PDFKit好像會自動建立index
        if(self.pdfDocument != nil){
            self.searchText(text: "太陽篇")
        }
    }
    
    private func notInitialized() -> Bool{
        let finish = self.append(withPathComponent: "finish")
        let finishFilePath = (finish?.path)!
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: finishFilePath) {
            return false
        }else{
            return true
        }
    }
    
    private func loadPdfDataFromBundle() -> Data?{
        var returnData: Data?
        let myUrl = Bundle.main.url(forResource: "pdf-sample", withExtension: "pdf")!
        let pdfData = try? Data(contentsOf: myUrl)
        if(!isStaging){
            do{
                returnData = try pdfData?.aesDecrypted(_key: self.loadKey())
            }catch{
                print("Decrypt data from bundle failed: " + error.localizedDescription)
            }
        }else{
            returnData = pdfData
        }
        return returnData
    }
    
    private func loadPdfDataFromDirectory() -> Data?{
        var decrypted: Data?
        let uuid = (UIDevice.current.identifierForVendor?.uuidString.replacingOccurrences(of: "-", with: "").prefix(16))!
        let pdfData = read(withPathComponent: "content")
        if(pdfData != nil){
            let key = String(uuid) + self.innerKey
            do{
                decrypted = try pdfData?.aesDecrypted(_key: key)
            }catch{
                print("Decrypt data from directory failed: " + error.localizedDescription)
            }
        }
        return decrypted
    }
    
    private func loadKey() -> String{
        return self.innerKey + self.key
    }
    
    fileprivate func setupThumbnailView() {
        
        thumbnailView = PDFThumbnailView()
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(thumbnailView)
        
        thumbnailView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor).isActive = true
        thumbnailView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true
        
        thumbnailView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        pdfView.bottomAnchor.constraint(equalTo: thumbnailView.bottomAnchor).isActive = true
        
        
        
        thumbnailView.backgroundColor = UIColor(displayP3Red: 179/255, green: 179/255, blue: 179/255, alpha: 0.5)
        thumbnailView.layoutMode = .horizontal
        thumbnailView.thumbnailSize = CGSize(width: 80, height: 100)
        thumbnailView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        thumbnailView.contentInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        thumbnailView.pdfView = pdfView
    }
    
    
        
    
    fileprivate func initializeContainerView() {
        self.searchBar.delegate = self
        self.currentPageTextBox.delegate = self
        self.previousBtn.isEnabled = false
        self.nextBtn.isEnabled = false
        
        let topLeft = self.containerView.frame.origin;
        if(isPad){
            self.containerView.frame.origin = CGPointMake(topLeft.x, topLeft.y-30)
        }
        
        let width = self.view.bounds.size.width
        
        let oldPosition = self.nextBtn.layer.position
        self.nextBtn.layer.position = CGPointMake(width - 23, oldPosition.y)
        self.nextBtn.setTitle("\u{25B6}", for: UIControlState.normal)
        self.nextBtn.contentHorizontalAlignment = .right;
        
        self.previousBtn.layer.position = CGPointMake(width - 52, oldPosition.y)
        self.previousBtn.setTitle("\u{25C0}", for: UIControlState.normal)
        self.previousBtn.contentHorizontalAlignment = .left

        //self.previousBtn.layer.borderWidth = 1;
        //self.previousBtn.layer.borderColor = UIColor.gray.cgColor
        
        
        self.searchResultLabel.layer.position = CGPointMake(width - 145, oldPosition.y)
        
        let pageOldPosition = self.totalPageLabel.layer.position
        self.totalPageLabel.layer.position = CGPointMake(width - 30, pageOldPosition.y)
        self.currentPageTextBox.layer.position = CGPointMake(width - 80, pageOldPosition.y)
    }
    
    fileprivate func setFinishFlag() {
        if let filePath = self.append(withPathComponent: "finish"){
            do{
                if let data = "FINISH".data(using: .utf8){
                    try data.write(to: filePath)
                }
            }catch{
                print("Finish file not written to directory: " + error.localizedDescription)
            }
        }
    }
    
    fileprivate func initializeApp() {
        
        initializeContainerView()
        setupPdfView()
        loadPdfDocument()
        setupThumbnailView()
        setupOutlineButton()
        
        
        //add tap gesture recognizer to pdfView
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(pdfViewTapped))
        self.pdfView.addGestureRecognizer(tapGestureRecognizer)
        
        //add double tap gesture recognizer to root view and do nothing, double tap envent should pass to pdfView
        doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(pdfViewDoubleTaped(_:)))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        //doubleTapGestureRecognizer.delegate = self
        self.view.addGestureRecognizer(doubleTapGestureRecognizer)
        tapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)
        //add page change handler
        NotificationCenter.default.addObserver (self, selector: #selector(handlePageChange), name: Notification.Name.PDFViewPageChanged, object: nil)
        
        
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(viewEnterForegroud),
                                               name: NSNotification.Name.UIApplicationWillEnterForeground,
                                               object: nil)
        if(!self.loadingKeyFromCloudFailed && self.internetConnectionAvailable){
            setFinishFlag()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if(notInitialized()){
            self.loadKeyFromCloudAndInitialzeApp()
        }else{
            initializeApp()
        }
    }
    
    private func loadKeyFromCloudAndInitialzeApp() {
        
        let reachability = Reachability(hostName: "www.apple.com")
        if(reachability?.currentReachabilityStatus().rawValue == 0){
            //synchronous, 錯誤會在ViewDidAppear處理
            self.internetConnectionAvailable = false
            self.initializeApp()
        }else{
            self.internetConnectionAvailable = true
           
            //asynchronous, ViewDidAppear應該已經完成，所以錯誤在這裡處理
            CloudDAO.fetch { (result) in
                switch result {
                case .success(let myKey):
                    self.key = myKey
                    self.initializeApp()
                    self.loadingKeyFromCloudFailed = false
                    self.showEveryThing()
                case .failure(let error):
                    print(error)
                    self.loadingKeyFromCloudFailed = true
                    self.alertMessage(message: "程式初始發生錯誤，請確認連上網際網路，並重新開啟程式。")
                    self.initializeApp()
                    self.hideEveryThing()
                }
            }
        }
    }
    
    @objc func viewEnterForegroud() -> Void{
        self.reloadTransitionImage()
        if(self.loadingKeyFromCloudFailed || !self.internetConnectionAvailable){
            self.loadKeyFromCloudAndInitialzeApp()
        }
    }
    
    private func reloadTransitionImage() -> Void{
        let imageName = "cover.png"
        let image = UIImage(named: imageName)
        let imageView = UIImageView(image: image!)
        let orign = view.frame.origin
        let y = isPad ? orign.y : orign.y + 150
        let height = isPad ? view.frame.height : view.frame.height - 200
        
        imageView.frame = CGRect(x: orign.x, y: y, width: view.frame.width, height: height)
        view.addSubview(imageView)
        view.bringSubview(toFront: imageView)
        
        
        UIView.animate(withDuration: 2, animations: {
            imageView.alpha = 0
        }, completion: nil)
        
         
    }
    
    
    fileprivate func alertMessage(message: String) {
            let dialogMessage = UIAlertController(title: message, message: "", preferredStyle: .alert)
            let ok = UIAlertAction(title: "確認", style: .default, handler: { (action) -> Void in
                
            })
            dialogMessage.addAction(ok)
            self.present(dialogMessage, animated: true, completion: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.reloadTransitionImage()
        
        if(!self.internetConnectionAvailable){
            self.hideEveryThing()
            alertMessage(message: "請檢查網路連線是否正常，並重新開啟程式。")
            return;
        }
        
        if(self.loadingError){
            self.hideEveryThing()
            alertMessage(message: "程式初始發生錯誤，請移除並重新下載安裝。")
            return;
        }
        
        self.showEveryThing()
        
    }
    
    func hideEveryThing() -> Void{
        self.view.isHidden = true
    }
    
    func showEveryThing() -> Void{
        self.view.isHidden = false
    }
    
    
    
    @available(iOS 13.0, *)
    override func buildMenu(with builder: UIMenuBuilder) {
        builder.remove(menu: .share)
        builder.remove(menu: .help)
        builder.remove(menu: .lookup)
        builder.remove(menu: .learn)
    }

    //結束編輯
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return self.finishEditing()
    }
    
    func finishEditing() ->Bool{
        self.view.endEditing(true)
        //檢查數字
        let digitsCharacters = CharacterSet(charactersIn: "0123456789")
        let pageIndexText = self.currentPageTextBox.text
        let isDigit =  CharacterSet(charactersIn: pageIndexText ?? "A").isSubset(of: digitsCharacters)
        
        let pageNumber = Int(self.currentPageTextBox.text ?? "1") ?? 1
        let exceedPageNumber = pageNumber > self.totalPageCount
        
        if(!isDigit || exceedPageNumber || pageNumber <= 0){
            if let currentPage = pdfView.currentPage,
               let pageIndex: Int = pdfView.document?.index(for: currentPage) {
                self.currentPageTextBox.text = "\(pageIndex + 1)"
            }
        }else{
            let targetPage = pdfView.document!.page(at: (pageNumber - 1))
            self.pdfView.go(to: targetPage!)
        }
        return true
    }
    
    @objc func handlePageChange() -> Void{
        if let currentPage: PDFPage = pdfView.currentPage,
           let pageIndex: Int = pdfView.document?.index(for: currentPage) {
            self.currentPageTextBox.text = "\(pageIndex + 1)"
        }
    }
    
    func showOrHide(view: UIView) -> Void {
        if(self.thumbnailViewShow == false){
            self.showThumbnameVIew(view: self.thumbnailView)
            self.thumbnailViewShow = true
        }else{
            self.thumbnailViewShow = false
            self.hideThumbnailView(view: self.thumbnailView)
        }
    }
    
    func showThumbnameVIew(view: UIView) ->Void{
        UIView.animate(withDuration: 0.3, animations: {
            view.alpha = 1
        }, completion: nil)
    }
    
    func hideThumbnailView(view: UIView) ->Void{
        UIView.animate(withDuration: 0.3, animations: {
            view.alpha = 0
        }, completion: nil)
    }
    
    
    @objc func pdfViewTapped() -> Void {
        _ = self.finishEditing()
        showOrHide(view: self.thumbnailView)
        self.toggleTools()
    }
    
    @objc func pdfViewDoubleTaped(_ gesture: UITapGestureRecognizer) -> Void {
        
    }
    
    
    
    func toggleTools() {
        if outlineButton.alpha != 0 {
            UIView.animate(withDuration: 0.3, animations: {
                self.outlineButton.alpha = 0
                //self.thumbnailView.alpha = 0
            }, completion: nil)
        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.outlineButton.alpha = 1
                //self.thumbnailView.alpha = 1
            }, completion: nil)
        }
    }
    
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        self.selections.removeAll()
        self.pdfView.highlightedSelections = []
        self.searchResultLabel.text = ""
        self.previousBtn.isEnabled = false
        self.nextBtn.isEnabled = false
        return true
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.searchBar.resignFirstResponder()
        if let searchText = searchBar.text {
            self.searchText(text: searchText)
        }
        
    }
    
    private func searchText(text : String) -> Void{
        if self.pdfDocument.isFinding {
            self.pdfDocument.cancelFindString()
        }
        self.pdfDocument.beginFindString(text, withOptions: .caseInsensitive)
    }

    func didMatchString(_ instance: PDFSelection) {
        instance.color = UIColor.yellow
        self.selections.append(instance)
    }
    
    func documentDidEndDocumentFind(_ notification: Notification) {
        //文件超動後會有第一次的initial動作，這時候不是真的user搜尋，不需要highlight
        if(!seachInitialized){
            seachInitialized = true
            return
        }
        self.pdfView.highlightedSelections = self.selections
        
        if(!self.pdfView.highlightedSelections!.isEmpty){
            if let current = self.pdfView.highlightedSelections?[0]{
                //current.color = UIColor.red
                self.pdfView.setCurrentSelection(current, animate: true)
                self.pdfView.go(to:current)
                self.currentSelectionIndex = 0
                self.searchResultLabel.text = "找到\(self.pdfView.highlightedSelections?.count ?? 0)筆資料"
                //self.searchResultLabel.isHidden = false
                self.nextBtn.isEnabled = true
            }
        }else{
            self.searchResultLabel.text = "找到0筆資料"
            self.previousBtn.isEnabled = false
            self.nextBtn.isEnabled = false
        }
    }
    
    @IBAction func nextBtnClicked(_ sender: UIButton) {
        if(!self.pdfView.highlightedSelections!.isEmpty){
            let nextIndex = self.currentSelectionIndex + 1;
            if(nextIndex >  self.pdfView.highlightedSelections!.count - 1){
                self.lastSelectionAlert()
            }else{
                if let current = self.pdfView.highlightedSelections?[nextIndex]{
                    self.currentSelectionIndex = nextIndex
                    self.pdfView.setCurrentSelection(current, animate: true)
                    self.pdfView.go(to:current)
                    self.previousBtn.isEnabled = true
                }
            }
        }
    }
    
    @IBAction func previousBtnClicked(_ sender: UIButton) {
        if(!self.pdfView.highlightedSelections!.isEmpty){
            let nextIndex = self.currentSelectionIndex - 1;
            if(nextIndex <  0){
                //self.alertMessage()
            }else{
                if let current = self.pdfView.highlightedSelections?[nextIndex]{
                    self.currentSelectionIndex = nextIndex
                    self.pdfView.setCurrentSelection(current, animate: true)
                    self.pdfView.go(to:current)
                    if(nextIndex == 0){
                        self.previousBtn.isEnabled = false
                    }
                }
            }
        }
    }
    
    private func lastSelectionAlert(){
        // Create Alert
        let dialogMessage = UIAlertController(title: "已到搜尋結果最尾端！", message: "", preferredStyle: .alert)

        // Create OK button with action handler
        let ok = UIAlertAction(title: "確認", style: .default, handler: { (action) -> Void in
            if let current = self.pdfView.highlightedSelections?[0]{
                //current.color = UIColor.red
                self.pdfView.setCurrentSelection(current, animate: true)
                self.pdfView.go(to:current)
                self.currentSelectionIndex = 0
                self.previousBtn.isEnabled = false
                //self.searchResultLabel.isHidden = false
            }
        })
        //Add OK and Cancel button to an Alert object
        dialogMessage.addAction(ok)
        // Present alert message to user
        self.present(dialogMessage, animated: true, completion: nil)
    }
    //document directory
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    private func append(withPathComponent pathComponent: String) -> URL? {
        let url = getDocumentsDirectory().appendingPathComponent(pathComponent)
        return url
    }
    
    private func read(withPathComponent pathComponent: String)-> Data? {
        var returnData: Data?
        let url = getDocumentsDirectory().appendingPathComponent(pathComponent)
        do{
            returnData = try Data(contentsOf: url)
        }catch{
            print("Faild to load data from: " + url.absoluteString)
        }
        return  returnData
    }
    
    private func debugAlert(message: String){
        // Create Alert
        let dialogMessage = UIAlertController(title: message, message: "", preferredStyle: .alert)

        // Create OK button with action handler
        let ok = UIAlertAction(title: "確認", style: .default, handler: { (action) -> Void in
            print("this a test")
        })
        //Add OK and Cancel button to an Alert object
        dialogMessage.addAction(ok)
        // Present alert message to user
        self.present(dialogMessage, animated: true, completion: nil)
    }
    
    private func setupOutlineButton() {
        let x = isPad ? view.frame.width - 200 : view.frame.width - 50
        let width = isPad ? 60 : 25
        let y =  isPad ? 200 : self.containerView.frame.height / 3.5
        
        outlineButton = UIButton(frame: CGRect(x: Int(x), y: Int(y), width: Int(width), height: Int(width)))
        outlineButton.layer.cornerRadius = outlineButton.frame.width/2
        outlineButton.setTitle("亖", for: .normal)
        let size = isPad ? 30 : 20
        outlineButton.titleLabel?.font = UIFont(name: "AppleSDGothicNeo-Bold", size: CGFloat(size))
        outlineButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 0, bottom: 0, right: 0)
        outlineButton.setTitleColor(.white, for: .normal)
        outlineButton.backgroundColor = .darkGray
        outlineButton.alpha = 0.7
        view.addSubview(outlineButton)
        outlineButton.addTarget(self, action: #selector(toggleOutline(sender:)), for: .touchUpInside)
    }
    
    @objc private func toggleOutline(sender: UIButton) {
        
        guard let outline = self.outline else {
            print("PDF has no outline")
            return
        }
        
        if(outlineViewController == nil ){
            outlineViewController = OutlineTableViewController(outline: outline, delegate: self, isPad: isPad)
            
            outlineViewController.preferredContentSize = CGSize(width: 600, height: 800)
            outlineViewController.modalPresentationStyle = UIModalPresentationStyle.popover
        }
        
        let popoverPresentationController = outlineViewController.popoverPresentationController
        popoverPresentationController?.sourceView = outlineButton
        popoverPresentationController?.sourceRect = CGRect(x: sender.frame.width/2, y: sender.frame.height, width: 0, height: 0)
        popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection.up
        popoverPresentationController?.delegate = self
        
        
        self.present(outlineViewController, animated: true, completion: nil)
    }
}

