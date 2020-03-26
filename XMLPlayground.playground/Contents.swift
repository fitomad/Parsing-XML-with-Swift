import Foundation

//
// MARK: - Estructuras -
//

public struct Author
{
    ///
    public var name: String = ""
    ///
    public var surname: String = ""
}


public struct Link
{
    ///
    public var provider: String = ""
    ///
    public var providerURI: String?

    ///
    public var bookURL: URL?
    {
        guard let uri = self.providerURI, let url = URL(string: uri) else
        {
            return nil
        }
        
        return url
    }
}

public struct Book
{
    ///
    public var title = ""
    ///
    public var publisher = ""
    ///
    public var publicationDateInformation: (year: Int, month: Int, day: Int)?
    ///
    public var overview = ""
    ///
    public var authors: [Author]?
    ///
    public var links: [Link]?
}

//
// MARK: - Protocolos empleados durante el parseado -
//

internal protocol AuthorParserDelegate: AnyObject
{
    ///
    func parser(_ authorParser: AuthorParser, didFinishParseAuthorsSection authors: [Author]) -> Void
}

internal protocol LinksParserDelegate: AnyObject
{
    ///
    func parser(_ linksParser: LinksParser, didFinishParseLinksSection links: [Link]) -> Void
}

//
// MARK: - Author Parser
//

public class AuthorParser: NSObject
{
    // MARK: - Tags -
    
    private let NameTag = "name"
    private let SurnameTag = "surname"
    
    private let AuthorSection = "author"
    private let AuthorsSection = "authors"
    
    ///
    internal weak var delegate: AuthorParserDelegate?
    
    ///
    private var actualElement: String
    
    ///
    private var authors: [Author]
    ///
    private var actualAuthor: Author?
    
    /**
     
     */
    override public init()
    {
        self.actualElement = ""
        self.authors = [Author]()
        
        super.init()
    }
}

extension AuthorParser: XMLParserDelegate
{
    ///
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) -> Void
    {
        if elementName == AuthorSection
        {
            self.actualAuthor = Author()
        }

        self.actualElement = elementName
    }
    
    ///
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) -> Void
    {
        if elementName == AuthorSection
        {
            if let actualAuthor = self.actualAuthor
            {
                self.authors.append(actualAuthor)
            }
        }

        if elementName == AuthorsSection
        {
            self.delegate?.parser(self, didFinishParseAuthorsSection: self.authors)
        }

        self.actualElement = ""
    }
    
    ///
    public func parser(_ parser: XMLParser, foundCharacters string: String) -> Void
    {
        if self.actualElement == NameTag
        {
            self.actualAuthor?.name.append(string)
        }
        
        if self.actualElement == SurnameTag
        {
            self.actualAuthor?.surname.append(string)
        }
    }
}

//
// MARK: - Link Parser
//

public class LinksParser: NSObject
{
    // MARK: - Tags -
    
    private let LinkTag = "link"
    private let BuyLinksSection = "buy_links"
    private let ProviderAttribute = "provider"
    
    ///
    internal weak var delegate: LinksParserDelegate?
    
    private var actualElement: String
    private var links: [Link]
    private var actualLink: Link?
    
    /**
     
    */
    override public init()
    {
        self.actualElement = ""
        self.links = [Link]()
        
        super.init()
    }
    
}

extension LinksParser: XMLParserDelegate
{
    ///
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) -> Void
    {
        if elementName == LinkTag
        {
            self.actualLink = Link()
            
            if let provider = attributeDict[ProviderAttribute]
            {
                self.actualLink?.provider = provider
            }
        }

        self.actualElement = elementName
    }
    
    ///
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) -> Void
    {
        if elementName == LinkTag
        {
            if let actualLink = self.actualLink
            {
                self.links.append(actualLink)
            }
        }
        
        if elementName == BuyLinksSection
        {
            self.delegate?.parser(self, didFinishParseLinksSection: self.links)
        }

        self.actualElement = ""
    }
    
    ///
    public func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data)
    {
        guard let stringValue = String(data: CDATABlock, encoding: .utf8) else
        {
            return
        }
        
        self.actualLink?.providerURI = stringValue
    }
    
    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error)
    {
        print("Author parsing error. \(parseError.localizedDescription)")
        parser.abortParsing()
    }
}

//
// MARK: - Book Parser -
//

public class BookParser: NSObject
{
    ///MARK: - TAGS -
    
    private let BooksSection = "books"
    private let BookSection = "book"
    private let AuthorsSection = "authors"
    private let BuyLinksSection = "buy_links"
    
    private let TitleTag = "title"
    private let OverviewTag = "overview"
    private let PublisherTag = "publisher"
    private let PublicationTag = "publication"
    
    private let YearAttribute = "year"
    private let MonthAttribute = "month"
    private let DayAttribute = "day"
    
    /// Parser de XML
    private var parser: XMLParser
    /// Tag en la que nos encontramos en un momento dado
    private var actualElement: String
    /// El parser que está *activo* en este momento
    private var actualParser: XMLParserDelegate?
    
    ///
    private var actualBook: Book?
    ///
    internal private(set) var books: [Book]
    
    /**
     
    */
    public init(data: Data)
    {
        self.actualElement = ""
        self.books = [Book]()
        
        self.parser = XMLParser(data: data)
        
        super.init()
        
        // Delegado
        self.parser.delegate = self
        
        // Empezamos a parsear
        parser.parse()
    }
}

extension BookParser: XMLParserDelegate
{
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:])
    {
        switch elementName
        {
            case BookSection:
                self.actualBook = Book()
            
            case AuthorsSection:
                let authorParser = AuthorParser()
                authorParser.delegate = self

                self.parser.delegate = authorParser
                self.actualParser = authorParser
            
            case BuyLinksSection:
                let linksParser = LinksParser()
                linksParser.delegate = self

                self.parser.delegate = linksParser
                self.actualParser = linksParser
            
            case PublicationTag:
                if let yearString = attributeDict["year"],
                   let monthString = attributeDict["month"],
                   let dayString = attributeDict["day"]
                {
                    if let year = Int(yearString), let month = Int(monthString), let day = Int(dayString)
                    {
                        self.actualBook?.publicationDateInformation = (year: year, month: month, day: day)
                    }
                }
            
            default:
                self.actualElement = elementName
        }
    }
    
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?)
    {
        if elementName == BookSection
        {
            if let actualBook = self.actualBook
            {
                self.books.append(actualBook)
            }
        }
        
        if elementName == BooksSection
        {
            self.parser.abortParsing()
        }
        
        self.actualElement = ""
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String)
    {
        if self.actualElement == TitleTag
        {
            self.actualBook?.title.append(string)
        }
        
        if self.actualElement == PublisherTag
        {
            print(string)
            self.actualBook?.publisher.append(string)
        }
    }
    
    public func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data)
    {
        guard let stringValue = String(data: CDATABlock, encoding: .utf8) else
        {
            return
        }
        
        if self.actualElement == OverviewTag
        {
            self.actualBook?.overview = stringValue
        }
    }
    
    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error)
    {
        print("Book parsing error. \(parseError)")
    }
}

extension BookParser: AuthorParserDelegate
{
    ///
    internal func parser(_ authorParser: AuthorParser, didFinishParseAuthorsSection authors: [Author]) -> Void
    {
        self.actualBook?.authors = authors
        
        self.parser.delegate = self
        self.actualParser = nil
    }
}

extension BookParser: LinksParserDelegate
{
    ///
    internal func parser(_ linksParser: LinksParser, didFinishParseLinksSection links: [Link]) -> Void
    {
        self.actualBook?.links = links
        
        self.parser.delegate = self
        self.actualParser = nil
    }
}

//
// MARK: - Test -
//

let documentURL = Bundle.main.url(forResource: "books", withExtension: "xml")

if let documentURL = documentURL, let data = try? Data(contentsOf: documentURL)
{
    let parser = BookParser(data: data)
    
    for book in parser.books
    {
        print(book.title)
        
        if let authors = book.authors
        {
            for author in authors
            {
                print("by \(author.name) \(author.surname)")
            }
        }
        
        if let links = book.links
        {
            print("Se puede comprar en...")
            
            for link in links
            {
                print("\(link.provider) \(link.providerURI ?? "No disponible") ")
            }
        }
    }
}
