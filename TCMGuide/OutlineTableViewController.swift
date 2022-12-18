import UIKit
import PDFKit


class Section{
    let title: String
    let destination: PDFDestination
    var sections: [Section]
    var level: Int
    var isOpened: Bool = false
    
    init(title: String, sections: [Section] = [], isOpened: Bool = false, destination: PDFDestination, level: Int){
        self.title = title
        self.sections = sections
        self.isOpened = isOpened
        self.destination = destination
        self.level = level
    }
    
    func addSection(section: Section) -> Void{
        self.sections.append(section)
    }
}


protocol OutlineDelegate: class {
    func goTo(page: PDFPage)
}

class OutlineTableViewController: UITableViewController {
    
    let outline: PDFOutline
    weak var delegate: OutlineDelegate?
    var sections: [Section] = []
    let isPad: Bool
    var lastSection: Int = -1
    var lastRow: Int = -1
    var lastIndexPath: IndexPath?
    
    init(outline: PDFOutline, delegate: OutlineDelegate?, isPad:Bool) {
        self.outline = outline
        self.delegate = delegate
        self.isPad = isPad
        super.init(nibName: nil, bundle: nil)
        
        
        let numberOfChildren = outline.numberOfChildren
        if(numberOfChildren > 0){
            for i in 0...numberOfChildren - 1{
                let outline = outline.child(at: i)
                self.buildSections(outline: outline!, parent: nil, level: 0)
            }
        }
    }
    
    func buildSections(outline: PDFOutline, parent: Section?, level: Int){
        /*
        var indent: String = "";
        for _ in 0...level{
            if(level != 0){
                indent += "     "
            }
        }
         */
        
        let section = Section(title: outline.label!,  destination: outline.destination!, level: level)
        if(level == 0 || level == 1){
            self.sections.append(section)
        }else{
            parent?.sections.append(section)
        }
        
        let numberOfChildren = outline.numberOfChildren
        if(numberOfChildren > 0){
            for i in 0...numberOfChildren - 1{
                let child = outline.child(at: i)
                self.buildSections(outline: child!, parent: section, level: level + 1)
            }
        }
    }
    
    
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.isScrollEnabled = true
        if(!isPad){
            tableView.rowHeight = 30
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if let indexPath = self.lastIndexPath{
            self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }
    
    
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = self.sections[section]
        if(section.isOpened){
            return section.sections.count + 1
        }else{
            return 1
        }
        
        //return outline.numberOfChildren
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) ->
    UITableViewCell {
        let cell =
            tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as UITableViewCell
        /*
        cell.backgroundColor = .gray
        
        cell.textLabel?.textColor = .white
        cell.textLabel?.tintColor = .white
         */
        let size = isPad ? 25 : 12
        cell.textLabel?.font = UIFont.boldSystemFont(ofSize: CGFloat(size))
        let section = self.sections[indexPath.section]
        let level = section.level
        var indent: String = "";
        for _ in 0...level{
            if(level != 0){
                indent += "     "
            }
        }
        
        if(indexPath.row == 0){
            if(section.sections.count > 0){
                if(section.isOpened){
                    cell.textLabel?.text = indent + "\u{2796}" + sections[indexPath.section].title
                }else{
                    cell.textLabel?.text = indent + "\u{2795}" + sections[indexPath.section].title
                }
            }else{
                cell.textLabel?.text = indent + section.title
            }
        }else{
            cell.textLabel?.text = indent +  "     "  +   "     "  +  section.sections[indexPath.row - 1].title
        }
        
        return cell
        
        //if let label = cell.textLabel, let title = outline.child(at: indexPath.row)?.label {
        //    label.text = String(title)
        //}
        
        
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //tableView.deselectRow(at: indexPath, animated: true)
        
        var rowSelected = true
        
        var section : Section
        
        if (indexPath.row == 0){
            section = self.sections[indexPath.section]
            var lastOpened = false
            if(section.sections.count > 0){
                if(section.isOpened){
                    lastOpened = true
                }else{
                    tableView.deselectRow(at: indexPath, animated: true)
                    self.lastRow = 0
                    rowSelected = false
                }
                
                section.isOpened = !section.isOpened
                tableView.reloadSections([indexPath.section], with: .none)
                
                if(lastOpened){
                    tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                }
            }else{
                tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            }
            
            //tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        }else{
            section = self.sections[indexPath.section].sections[indexPath.row - 1]
        }
        
        self.lastSection = indexPath.section
        self.lastRow = indexPath.row
        
        
        let destination = section.destination
        if let page = destination.page {
            delegate?.goTo(page: page)
        }
        if(rowSelected &&  !isPad){
            self.dismiss(animated: true)
        }
    }
    

}
