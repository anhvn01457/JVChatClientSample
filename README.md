# Sử dụng Socket để kết nối giữa iOS app và Web Server

Rất nhiều ứng dụng iOS sử dụng HTTP để giao tiếp với web server bởi tính tiện dụng, dễ sử dụng và được hỗ trợ rộng rãi của nó.

Tuy nhiên trong một vài trường hợp bạn sẽ cần sử dụng tầng thấp hơn HTTP và giao tiếp với server của bạn bằng việc sử dụng TCP sockets.

Lợi ích của việc này có rất nhiều, ví dụ như:


* Bạn có thể gửi chính xác dữ liệu bạn muốn gửi giúp cho giao thức (protocol) của bạn gọn gàng và hiệu quả.
* Bạn có thể gửi dữ liệu tới client (đã kết nối) bất kỳ khi nào bạn muốn thay vì bắt client phải kiểm tra để lấy về (poll).
* Bạn có thể viết socket server của riêng bạn mà không bị phụ thuộc vào các web server sẵn có với ngôn ngữ bạn lựa chọn.
* Đôi khi bạn bị buộc phải sử dụng socket vì bạn không có quyền thay đổi cách thức giao tiếp của server.

Trong bài viết này, bạn sẽ trải nghiệm việc viết một ứng dụng iOS giao tiếp với một TCP socket server bằng cách sử dụng NSStream/CFStream.

Ứng dụng iOS và server sẽ thực hiện chức năng chat để bạn có thể chat trên nhièu thiết bị cùng nhau theo thời gian thực (real-time).

Trước tiên chúng ta cần tìm hiểu một chút để hiểu về socket đã nhé.

## Socket là gì?

Socket là một tool cho phép bạn truyền dữ liệu theo các 2 hướng.

Như vậy nghĩa là 1 socket sẽ có 2 phía như bạn có thể nhìn trong ảnh bên dưới: một phía là bạn, phía còn lại là người khác, thông thường là một process khác, có thể ở trên cùng một máy hoặc máy khác thông qua mạng.

![sockets.jpg](https://viblo.asia/uploads/images/4d425fdfbf31fe702f3c5f81cfc7adee316fcf0a/5a61a241cc08225e84b04dc98e1b144b753f0230.jpg)

Mỗi phía được xác định bằng 2 thành phần là địa chỉ IP và Port. IP dùng để xác định địa chỉ của thiết bị (computer) còn port được kết nối tới 1 process.

Có rất nhiều dạng socket khác nhau phụ thuộc vào sự khác biệt giữa cách truyền dữ liệu (protocol). Dạng phổ biến nhất là TCP và UDP. Trong bài viết này, chúng ta sẽ làm việc với TCP socket.

## Client và Server

Sẽ là một thiếu sót lớn nếu nói về socket mà không nói về client và server. Bạn hãy nghĩ về nó tương tự như một nhà hàng.

Server là một tiến trình (process) lắng nghe các kết nối từ các client. Bạn có thể nghĩ nó giống như là vị trí lễ tân đứng chào khách ở cửa.

Vì có rất nhiều client có thể cố kết nối hoặc yêu cầu cùng lúc, server thường khởi tạo các tiền trình con cho mỗi kết nối được thiết lập riêng với mỗi client. Hãy nghĩ nó giống như khi lễ tân dẫn bạn và bàn và chỉ định người phục vụ bàn riêng cho bạn.

Một khi kết nối được thiết lập, client và server có thể bắt đầu gửi và nhận dữ liệu thông qua socket mà chúng sử dụng. Bạn có thể hình dung việc này giống như khách hàng và bồi bàn bắt đầu nói chuyện với nhau (ví dụ hỏi về nhà hàng nay có món gì đặc biệt chẳng hạn)

Socket sẽ được đóng khi client đóng việc giao tiếp hoặc khi server dừng lại. Từ thời điểm đó, bất kỳ cố gắng sử dụng socket (đã đóng) sẽ gặp kết quả lỗi. Việc này có thể giống như việc phục vụ bàn cảm thấy quá bị xúc phạm khi gặp phải vị khách quá khiếm nhã nên quyết định đuổi vị khách đó ra khỏi nhà hàng và quát: "im" mỗi khi vị khách cố gắng nói gì đó (ví dụ này hơi thiếu tính thực tế nhỉ - nhưng đại loại sự việc là như thế đó)

## Tổng quan về Server

Trước khi bắt đầu viết ứng dụng iOS, chúng ta sẽ cần chuẩn bị một server để thực hiện các tác vụ sau:

* Lắng nghe các kết nối tới từ client
* Theo dõi các client đã kết nối (xác định bởi socket và tên)
* Gửi đi các sự kiện (ví dụ như khi có user mới tham gia vào group chat)

Để gửi đi các sự kiện, server cần khai báo một protocol định nghĩa hình thức dữ liệu mà client/server gửi đi và về.

Trong ứng dụng này, chúng ta sẽ sử dụng một protocol đơn giản dựa trên string.

Ví dụ, khi user tham gia vào chat, iPhone của họ sẽ gửi một chuỗi (string) đến server như này:

iam:iphoneServer sẽ tìm kiếm chuỗi iam và xác định đó là sự kiện "user tham gia vào chat" và xử lý nó một cách thích hợp, trong ứng dụng này sẽ là thông báo cho các client đã kết nối rằng có user iphone gia nhập. Một xử lý tương tự nữa là khi user gửi message, đó sẽ là chuỗi:

msg:noidungmessageĐể xây dựng server TCP đơn giản này, bạn có thể chọn nhiều ngôn ngữ khác nhau, tuy nhiên trong ví dụ này tôi sẽ dùng Python. Bạn có thể xẩy dựng server này với các API có sẵn của Python nếu bạn muốn nhưng để mọi thứ dễ dàng hơn, tôi sẽ sư dụng một framework của Python tập trung vào xử lý mạng, đó là Twisted.

### Twisted là gì?

Twisted là một event-based engine giúp cho việc xây dựng các ứng dụng web sử dụng TCP, UDP, SSH, IRC hay FTP dễ dàng hơn.

Nếu chúng ta xây dựng một server TCP từ đầu, chúng ta sẽ cần học về Python, các thủ thuật xử lý với socket và network. Nhưng Twisted đi kèm với một tập hợp các class để quản lý kết nối và điều phối sự kiện nên chúng ta có thể tập trung vào chức năng chính của app đó là gửi đi các message.

Twisted được xây dựng quanh một design pattern mà bạn có thể đã nghe đến, được gọi là [reactor pattern](http://en.wikipedia.org/wiki/Reactor_pattern). Pattern này tuy đơn giản nhưng rất mạnh mẽ, nó sẽ bắt đầu một vòng lặp, chờ đợi các sự kiện rồi xử lý chúng, như các bạn thấy trong ảnh dưới đây:

![reactor-1.jpg](https://viblo.asia/uploads/images/4d425fdfbf31fe702f3c5f81cfc7adee316fcf0a/e17d8fa5f4669a919b03baa0fed6520097e159aa.jpg)

### Cài đặt Twisted

Nếu bạn sử dụng Mac OS X (hẳn rồi) thì Python đã được cài sẵn và theo bài viết tôi tham khảo thì nó nên có sẵn framework Twisted từ OS X 10.6 nhưng có vẻ cuộc đời không như là mơ, khi sử dụng Twisted trên OS 10.11.4 thì tôi gặp lỗi ImportError: No module named twisted.internet. Tôi đã xử lý bằng cách cài lại Python bằng [Homebrew](http://brew.sh/) sau đó dùng pip để cài Twisted bằng 3 câu lệnh dưới đây:

```
brew install python
brew linkapps python
pip install twisted
```

### Xây dựng server TCP đơn giản

Bởi vì có lẽ bạn sẽ không hứng thú với Python ngay lúc này, nên tôi sẽ cung cấp sẵn nội dụng của server thực hiện các chức năng nói trên, bạn có thể nhìn qua và chắc là sẽ hiểu nghiệp vụ của nó một cách không quá khó. Nếu có điều gì khó hiểu thì hãy comment hỏi lại tôi nhé. Còn việc của bạn bây giờ là tạo ra một file có tên là server.py và paste nội dung đoạn code sau vào:

```python
from twisted.internet.protocol import Factory, Protocol
from twisted.internet import reactor

class IphoneChat(Protocol):
    def connectionMade(self):
        self.factory.clients.append(self)
        print "clients are ", self.factory.clients

    def connectionLost(self, reason):
        self.factory.clients.remove(self)

    def dataReceived(self, data):
        a = data.split(':')
        print a
        if len(a) > 1:
            command = a[0]
            content = a[1]

            msg = ""
            if command == "iam":
                self.name = content
                msg = self.name + " has joined"

            elif command == "msg":
                msg = self.name + ": " + content
            
            print msg

            for c in self.factory.clients:
                c.message(msg)
                
    def message(self, message):
        self.transport.write(message + '\n')

factory = Factory()
factory.protocol = IphoneChat
factory.clients = []

reactor.listenTCP(80, factory)
print "Iphone Chat server started"
reactor.run()
```

Hãy chú ý dòng thứ 3 từ dưới lên, ở đó chúng ta quyết định port của server là 80.

Bây giờ hãy mở Terminal lên, đi đến thư mục chứa file server.py này và gõ dòng lệnh sudo python server.py để chạy server. Bạn sẽ thấy Iphone Chat server startedThay vì việc bắt đầu xây dựng ứng dụng iOS client ngay bây giờ thì chúng ta sẽ dùng telnet để kiểm tra kết nối. Hãy mở tab (hoặc window) khác của terminal và gõ lệnh:

```
telnet localhost 80
```

Nếu mọi thứ hoạt động bình thường thì ở tab/window chạy server, bạn sẽ thấy màn hình hiện dòng chữ tưong tự clients are [<__main__.IphoneChat instance at 0x102d11f38>]. Còn ở tab/window mà bạn sử dụng telnet sẽ hiện ra:

```
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
```

Nếu mọi thứ đúng như trên (và nên thế) thì bạn có thể bước sang bước tiếp theo là xây dựng ứng dụng iOS client rồi.

## Ứng dụng iOS Client

Bây giờ thì server đã sẵn sàng rồi, chúng ta sẽ tập trung vào việc xây dựng ứng dụng client. Ứng dụng này sẽ quản lý ba tác vụ chính:

1. Tham gia vào phòng chat
1. Gửi message
1. Nhận message (và hiển thị)

Để đơn giản ứng dụng, chúng ta sẽ sư dụng một view chính và chứa hai view con. Một cho phần login - tham gia vào chat room và một cho màn hình chat - nơi hiển thị message nhận được và gửi đi message. Bạn có thể nhìn sơ đồ trong ảnh dưới để hiểu hơn:

![views diagram.jpg](https://viblo.asia/uploads/images/4d425fdfbf31fe702f3c5f81cfc7adee316fcf0a/0e1ec6f3b7223979c9a1fe146d28805579758a53.jpg)

Nào, tổng quan là thế rồi, hãy bắt đầu bằng cách khởi tạo một project mới trong Xcode dạng Single View Application.

Mở file Main.storyboard để tạo view cho app. Kéo 1 UIView vào để làm view cho join chat. Trong view đó chúng ta kéo thêm 1 UITextField và 1 UIButton Join như hình dưới:

![join view](https://viblo.asia/uploads/images/4d425fdfbf31fe702f3c5f81cfc7adee316fcf0a/3d85683bdf809f64bb1ac4e70c5c1630e48322aa.png)

UITextField dùng để nhập nickname tham gia vào chat và UIButton dùng để gọi hành động tham gia.

Tiếp theo bạn cần tạo các IBOutlet và IBAction với ViewController. Với UIView thêm vào, bạn kéo IBOutlet và đặt tên là joinView, UITextField thì đặt tên là inputNameField còn UIButon thì tạo IBAction và đặt tên làjoinChat.

Ở thời điểm này, bạn đã có thể Run project và nhìn thấy view nhưng tất nhiên sẽ vẫn chưa có hoạt động gì. Bây giờ chúng ta sẽ viết code để thực hiện việc join chat bằng việc thiết lập kết nối với server. Nhưng trước đó, hãy tìm hiểu 1 chút về lập trình stream trong iOS đã nhé.

### Giới thiệu về lập trình Stream

Để tạo kết nối socket trên iOS chúng ta sử dụng stream. Một stream là một sự trừu tượng hoá thông qua cơ chế gửi và nhận dữ liệu. Dữ liệu có thể được đặt ở nhiều nơi ví dụ như trong một file, một C buffer hoặc một kết nối mạng. Ngoài ra, stream có một delegate liên kết giúp cho việc xử lý với các sự kiện đặc biệt như "kết nối được mở", "dữ liệu được nhận", "kết nối đã bị đóng" v.v..

Có 3 class quan trọng liên quan tới stream có sẵn trong Cocoa Framework:

1. NSStream : Đây là class cha, khai báo các đặc tính trừu tượng như open, close và delegate.
1. NSInputStream : Một class con của NSStream cho việc reading input.
1. NSOutputStream : Class con của NSStream cho việc writing input.

Các class này được xây dựng trên CFStream, một thành phần cấp thấp hơn thuộc về lớp Core Foundation. Nếu bạn cảm thấy đặc biệt dũng cảm, muốn nghiên cứu sâu hơn, bạn hoàn toàn có thẻ viết lại toàn bộ ứng dụng này sử dụng các class từ Core Foundation. Nhưng để cho bài viết này đơn giản, chúng ta sẽ tập trung vào các class NSStream - thứ dễ sử dụng hơn. Chỉ có một vấn đề là NSStream không thể kết nối tới remote host - điều mà ứng dụng của chúng ta cần.

Đừng vội lo lắng, NSStream và CFStream có thể kết nối với nhau, chúng ta có thể dễ dàng lấy một NSStream từ một CFStream chỉ với một hàm đặc biệt.

Nào hãy thử làm điều này bằng cách mở file ViewController.m lên, thêm các biến private instance sau:

```objc
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
```

Tiếp theo, bạn thêm method sau:

```objc
- (void)initNetworkCommunication {
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)@"localhost", 80, &readStream, &writeStream);
    inputStream = (NSInputStream *)CFBridgingRelease(readStream);
    outputStream = (NSOutputStream *)CFBridgingRelease(writeStream);
}
```

Hàm đặc biệt CFStreamCreatePairWithSocketToHost giúp chúng ta liên kết 2 stream với host và port. Một khi bạn đã gọi nó, bạn có thể ép kiểu CFStream về NSStream. Đây là cuộc dạo chơi duy nhất không phải là Objective-C của chúng ta.

Như vậy là chúng ta đã chuẩn bị cho việc kết nối nhưng vẫn chưa có sự liên lạc nào được thiết lập. Để mở nó, bạn sẽ cần gọi method open ở cả 2 stream, nhưng trước đó chúng ta vẫn còn việc phải làm.

Như phía trên chúng ta đã nói NSStream có delegate, bởi vậy trước khi mở kết nối, chúng ta phải _set_ nó nếu không chúng ta sẽ không nhận được bất kỳ thông báo nào. Chúng ta sẽ sử dụng luôn class hiện tại cho delegate. Để làm viẹc đó, bạn thêm 2 dòng lệnh sau vào cuối của method initNetworkCommunication:

```objc
    inputStream.delegate = self;
    outputStream.delegate = self;
```

Và tất nhiên, chúng ta cũng phải mở file ViewController.h và thêm NSStreamDelegate:

```objc
@interface ViewController : UIViewController <NSStreamDelegate>
```

Các stream của chúng ta phải liên tục sẵn sàng cho việc gửi và nhận dữ liệu. Để làm điều đó, chúng ta phải lên lịch cho stream nhận các event trong một run loop. Nếu chúng ta không ấn định một run loop, delegate sẽ khoá việc thực thi code cho tới khi không có dữ liệu gì trên stream để đọc hoặc ghi - điều mà chúng ta muốn tránh.

Ứng dụng của chúng ta phải phản hồi lại với những sự kiện của stream nhưng không bị phụ thuộc vào chúng. Run-loop tạo lịch để thực thi các code khác (nếu cần thiết) nhưng đảm bảo rằng bạn vẫn có thông báo khi có gì đó xảy ra trên stream.

Để thực hiện việc này, hãy thêm 2 dòng code sau vào cuối của method initNetworkCommunication:

```objc
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
```

Bây giờ chúng ta đã sẵn sàng để mở kết nối, thêm 2 dòng này tiếp theo:

```objc
    [inputStream open];
    [outputStream open];
```

Thêm một việc nữa phải làm là gọi method `initNetworkCommunication` khi view được load bằng cách thêm vào method `viewDidLoad`:

```objc
    [self initNetworkCommunication];
```

Nào, đến đây thì hãy compile và chạy app thử xem sao. Nếu như không có gì bất thường, hãy chú ý bên phàn output của server (ở trên Terminal), bạn sẽ thấy tương tự như bên dưới:

![client joined](https://viblo.asia/uploads/images/4d425fdfbf31fe702f3c5f81cfc7adee316fcf0a/66acaf707f077d669b4541a16c2ee50332ec6074.png)

### Tham gia vào Chat

Bây giờ chúng ta đã kết nối được tới server và sẵn sàng để tham gia vào chat.

Hãy nhớ rằng message để tham gia vào chat sẽ có dạng "iam:name" nên chúng ta sẽ xây dựng 1 string như thế và ghi nó lên outputStream.

Chú ý rằng chúng ta không thể ghi trực tiếp string lên stream. Chúng ta cần chuyển nó sang kiểu NSData trước. Nào, mở file ViewController.m lên và thay method joinChat bằng đoạn sau:

```objc
- (IBAction)joinChat:(id)sender {
    NSString *response = [NSString stringWithFormat:@"iam:%@", self.inputNameField.text];
    NSData *data = [[NSData alloc] initWithData:[response dataUsingEncoding:NSASCIIStringEncoding]];
    [outputStream write:[data bytes] maxLength:[data length]];
}
```

Việc gửi message trên stream đơn giản đến mức khó tin đúng không?

Compile và chạy thử, nhập tên vào text field và nhấn Join. Mở shell phía server (Terminal), bạn sẽ thấy tương tự như sau:

![User joined chat](https://viblo.asia/uploads/images/4d425fdfbf31fe702f3c5f81cfc7adee316fcf0a/6b4dbf18bd6c47cbb18b2038b594a09593d48e81.png)

### Tạo Chat View

Tiếp theo chúng ta cần tạo giao diện cho user gửi và hiển thị message chat.

Mở file Main.storyboard, kéo thêm 1 UIView vào để tạo view con (song song với joinView đã tạo). Chú ý thứ tự view thì view mới kéo thêm vào này sẽ nằm ở trên joinView trong danh sách view trong Document Outline . Mục đích là để khi app mới chạy thì sẽ hiện màn hình Join Chat trước. Chúng ta sẽ làm việc này sau khi đã làm xong view này.

Tiếp theo, trong view mới kéo vào, bạn kéo thêm Text Field, Button, Table View vào như hình dưới:

![Chat View](https://viblo.asia/uploads/images/4d425fdfbf31fe702f3c5f81cfc7adee316fcf0a/4ca13daee85f0c07bfb044840182abac1ed417f0.png)

Sau khi đã có view như thế, bạn cần kết nối các thành phần UI này với class ViewController. Tạo các IBOutlet và IBAction với file ViewController.h cho Text Field, Table View, View chứa các thành phần này lần lượt với tên inputMessageField, contentTableView, chatView. Kéo Button với IBAction tên sendMessage. Tiếp theo bạn set delegate và datasource cho Table View là View Controller bằng cách giữ control và kéo từ Table View vào View Controller (biểu tượng icon màu vàng) như hình dưới và chọn dataSource và delegate:

![set dataSource và delegate cho table view](https://viblo.asia/uploads/images/4d425fdfbf31fe702f3c5f81cfc7adee316fcf0a/57000f0a6f723ffd7c6948fd5e0f70ce6efd7d3e.png)

Bây giờ bạn đã hoàn thành xong UI cho Chat View, đừng quên kéo lại thứ tự cho Chat View lên trên Join View trong Document Outline để màn hình hiện ra Join View trước nhé:

![Views Order](https://viblo.asia/uploads/images/4d425fdfbf31fe702f3c5f81cfc7adee316fcf0a/5fece7fc4c6e58667bd28a98136fb4def265aaba.png)

Tiếp theo bạn cần sửa lại khai báo [@interface](https://viblo.asia/u/interface) ở ViewController.h như sau:

```objc
@interface ViewController : UIViewController <NSStreamDelegate, UITableViewDelegate, UITableViewDataSource>
```

Chuyẻn sang file .m và thêm các method mới sau:

```objc
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"ChatCellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    return cell;
}

```

Cuối cùng, bạn cần thêm 1 dòng code nhỏ để chuyển view sang Chat View sau khi user đã tham gia vào chat. Đơn giản chỉ thêm đoạn code sau vào cuối method `joinChat`:

```objc
    [self.view bringSubviewToFront:self.chatView];
```

Compile và chạy thử, sau khi nhập tên và chọn Join, bạn sẽ thấy giao diện mới xuất hiện.

### Gửi tin nhắn đi

Bây giờ chúng ta chỉ còn lại chức năng chính của ứng dụng đó là gửi và nhận tin nhắn (message) từ các thiết bị ngang hàng khác.

Chúng ta sẽ bắt đầu bằng việc xây dựng sendMessage - method mà chúng ta đã setup được gọi khi nhấn Send button bằng IBAction phía trên. Chúng ta sẽ xây dựng tương tự như join chat chỉ có điều thay thế iam:bằng msg::

```objc
- (IBAction)sendMessage:(id)sender {
    NSString *response = [NSString stringWithFormat:@"msg:%@", self.inputMessageField.text];
    NSData *data = [[NSData alloc] initWithData:[response dataUsingEncoding:NSASCIIStringEncoding]];
    [outputStream write:[data bytes] maxLength:[data length]];
}
```

Compile và chạy thử xem nào. Hãy thử tham gia và gửi đi tin nhắn để test. Nếu mọi việc bình thường, bên phía server shell (Terminal) bạn sẽ thấy nội dung tin nhắn xuất hiện.

### Nhận các tin nhắn

Thực tế thì ứng dụng của chúng ta cũng đang nhận các message (tin nhắn) từ server, chỉ có điều chúng ta chưa viết code để hiển thị chúng lên thôi. Vậy thì hãy bắt đầu với việc đó nhỉ.

Trước tiên chúng ta cần thêm 1 biến private instance ở ViewController.m bên trong [@interface](https://viblo.asia/u/interface) extension:

```objc
@interface ViewController () {
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
    NSMutableArray *messages;
}

@end
```

Tiếp theo chúng ta làm lần lượt các công việc sau:

1. Thêm vào cuối method `viewDidLoad`:
```objc
    messages = [@[] mutableCopy];
```
2. Trong method `- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath`, thêm đoạn code sau ngay trước `return cell`:
```objc
    NSString *message = (NSString *)messages[indexPath.row];
    cell.textLabel.text = message;
```
3. Thay thế `return 0` trong `- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section` với:
```objc
    return messages.count;
```

Thực ra những việc này rất cơ bản, chúng ta khai báo và khởi tạo 1 NSMutableArray để chứa danh sách các message và thiết lập table view để hiển thị chúng.

Bây giờ chúng ta còn phải xây dựng NSStream delegate. Như bạn còn nhớ, một trong những thành phần chính của NSStream là thuộc tính delegate được khai báo là NSStreamDelegate.

Khai báo của nó bao gồm message stream:handleEvent: - thứ mà cho phép ứng dụng của chúng ta phản hồi lại với các hoạt động xảy ra trên các stream. Chúng ta đã set delegate nên giờ chỉ cần xây dựng method sau cho việc kiểm tra các kiểu event.

Hãy làm việc này bằng cách thêm đoạn code đơn giản sau:

```objc
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    NSLog(@"%@ stream event: %lu", (aStream == inputStream) ? @"input" : @"output", (unsigned long)eventCode);
}
```

NSStreamEvent được khai báo như sau:

```objc
typedef NS_OPTIONS(NSUInteger, NSStreamEvent) {
    NSStreamEventNone = 0,
    NSStreamEventOpenCompleted = 1UL << 0,
    NSStreamEventHasBytesAvailable = 1UL << 1,
    NSStreamEventHasSpaceAvailable = 1UL << 2,
    NSStreamEventErrorOccurred = 1UL << 3,
    NSStreamEventEndEncountered = 1UL << 4
};
```

Bạn có thể thử nghịch 1 chút để xem điều gì sẽ xảy ra. Trong trường hợp này, chúng ta chỉ quan tâm tới các event:
* NSStreamEventOpenCompleted: chỉ để kiểm tra kết nối được được mở
* NSStreamEventHasBytesAvailable: điều cốt yếu để nhận message
* NSStreamEventErrorOccurred: để kiểm tra các vấn đề trong kết nối
* NSStreamEventEndEncountered: để đóng stream khi server tắt

Hãy xây dựng method theo những trường hợp mà chúng ta quan tâm:

```objc
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    NSLog(@"%@ stream event: %lu", (aStream == inputStream) ? @"input" : @"output", (unsigned long)eventCode);
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            NSLog(@"Stream opened");
            break;
        case NSStreamEventHasBytesAvailable:
            break;
        case NSStreamEventErrorOccurred:
            NSLog(@"Cannot connect to host!");
            break;
        case NSStreamEventEndEncountered:
            break;
        default:
            NSLog(@"Unknown Event");
            break;
    }
}
```

Điểm chính là trong trường hợp NSStreamEventHasBytesAvailable, ở đây chúng ta cần:

* Đọc bytes từ stream
* Tập hợp chúng trong một buffer (vùng đệm)
* Chuyển đổi buffer sang string
* Thêm string vào mảng các message
* Thông báo cho table để reload lại các message từ mảng

Thay xử lý trường hợp NSStreamEventHasBytesAvailable với đoạn sau:

```objc
        case NSStreamEventHasBytesAvailable: {
            if (aStream == inputStream) {
                uint8_t buffer[1024];
                NSInteger len;
                while ([inputStream hasBytesAvailable]) {
                    len = [inputStream read:buffer maxLength:sizeof(buffer)];
                    if (len) {
                        NSString *output = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];
                        if (output) {
                            NSLog(@"Server said: %@", output);
                            [self messageReceived:output];
                        }
                    }
                }
            }
            break;
        }
```

Đầu tiên chúng ta cần chắc chắn rằng sự kiện này đến từ inputStream. Sau đó chúng ta chuẩn bị buffer (size 1024 là đủ cho mục đích của bài viết này.

Cuối cùng chúng ta bắt đầu một vòng lặp while để tập hợp các bytes của stream. Method read sẽ trả về 0 khi không còn gì trong stream. Bởi vậy khi output lớn hơn 0 chúng ta convert buffer sang một string và in nó ra.

Chúng ta đã làm hầu hết các phần khó, bây giờ chỉ việc chứa string đó trong mảng các message và reload lại table view. Để làm điều này chúng ta thêm một method mới:

```objc
- (void)messageReceived:(NSString *)message {
    [messages addObject:message];
    [self.contentTableView reloadData];
}
```

Chúng ta đã hoàn thành ứng dụng rồi đấy! Hãy bật server lên, bật ứng dụng lên, mở them 1 telnet cùng lúc và thử gửi message đi và nhận lại nhé.

![Final](https://viblo.asia/uploads/images/4d425fdfbf31fe702f3c5f81cfc7adee316fcf0a/511701119892f87e501256304250cb54a72c28b6.png)

Bài viết tham khảo từ: [Networking Tutorial for iOS: How To Create A Socket Based iPhone App and Server](https://www.raywenderlich.com/3932/networking-tutorial-for-ios-how-to-create-a-socket-based-iphone-app-and-server)

Chỉnh sửa và update code cho phù hợp với Xcode 7.3.

Các bạn có thể tham khảo thêm source code ở [https://github.com/anhvn01457/JVChatClientSample](https://github.com/anhvn01457/JVChatClientSample)

Chú ý rằng trong đấy mình có thêm 2 tweak nhỏ nhé.

Hãy thử việc tạo socket này để gửi mail với 1 mail server nào mà các bạn có thể telnet để gửi mail xem sao nhé, khá thú vị đấy.

