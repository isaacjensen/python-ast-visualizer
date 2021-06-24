#include <vector>

using namespace std;

struct Node {
    string* type;
    string* value;
    vector<struct Node*> children; 

    public:
        Node(string* n, string* v) { //constructor for struct Node
            type = n;
            value = v;
        }
};