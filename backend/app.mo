import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Array "mo:base/Array";
import LlmCanister "mo:llm";
import Debug "mo:base/Debug";

actor NewsVerification {
    type User = {
        username: Text;
        password: Text;
    };

    type VerificationResult = {
        news: Text;
        result: Text;
    };

    type Feedback = {
        resultId: Nat;
        rating: Nat;
    };

    stable var userBuffer: [(Text, User)] = [];
    var users: HashMap.HashMap<Text, User> = HashMap.HashMap<Text, User>(
        10, Text.equal, Text.hash
    );

    var verificationHistory: [VerificationResult] = [];
    var feedbackList: [Feedback] = [];

    system func preupgrade() {
        userBuffer := Iter.toArray(users.entries());
    };

    system func postupgrade() {
        users := HashMap.fromIter<Text, User>(
            Iter.fromArray(userBuffer),
            10,
            Text.equal,
            Text.hash
        );
    };

    public func register(username: Text, password: Text): async Text {
        if (users.get(username) != null) {
            return "⚠️ Username sudah terdaftar!";
        };

        let newUser: User = { username = username; password = password };
        users.put(username, newUser);

        return "✅ Registrasi berhasil!";
    };

    public func login(username: Text, password: Text): async Text {
        switch (users.get(username)) {
            case (null) { return "❌ User tidak ditemukan!"; };
            case (?user) {
                if (user.password == password) {
                    return "✅ Login sukses!";
                } else {
                    return "❌ Password salah!";
                };
            };
        };
    };

    public func isUserExists(username: Text): async Bool {
        return users.get(username) != null;
    };

    public func verifyNews(news: Text) : async Text {
        if (Text.size(news) == 0) {
            return "{\"error\": \"Berita tidak boleh kosong.\"}";
        };

        let verificationPrompt = 
            "Analisis berita berikut dan tentukan apakah itu hoax atau fakta.\n" #
            "Gunakan AI untuk menghasilkan kesimpulan dalam format JSON.\n" #
            "Berita: " # news;

        let result = await LlmCanister.prompt(#Llama3_1_8B, verificationPrompt);

        let verificationResult: VerificationResult = {
            news = news;
            result = result;
        };
        verificationHistory := Array.append(verificationHistory, [verificationResult]);

        Debug.print("LLM Response: " # result);
        return result;
    };

    public func getVerificationHistory() : async [VerificationResult] {
        return verificationHistory;
    };

    public func submitFeedback(resultId: Nat, rating: Nat) : async Text {
        if (rating < 1 or rating > 5) {
            return "{\"error\": \"Rating harus antara 1 dan 5.\"}";
        };

        feedbackList := Array.append(feedbackList, [{ resultId = resultId; rating = rating }]);
        return "{\"success\": \"Feedback diterima.\"}";
    };

    // Fungsi tambahan untuk frontend
    public func getUserList(): async [(Text, User)] {
        return Iter.toArray(users.entries());
    };

    public func deleteUser(username: Text): async Text {
        if (users.remove(username) == null) {
            return "❌ User tidak ditemukan!";
        };
        return "✅ User berhasil dihapus!";
    };

    public func getFeedbackList(): async [Feedback] {
        return feedbackList;
    };

    public func clearVerificationHistory(): async Text {
        verificationHistory := [];
        return "✅ Riwayat verifikasi berhasil dihapus!";
    };
};
