#include <iostream>
#include <set>
#include "parser.hpp"

extern int yylex();
extern struct Node* root;

using namespace std;

/*
 * These values are globals defined in the parsing function.
 */
extern string* target_program;
extern set<std::string> symbols;

void travelChildren(struct Node*, int);
void printNode(struct Node*, int);

void printNode(struct Node* node, int level) {
	cout << "\tn" << level << "[label = \"" << *(node->type) << ' ' << *(node->value) << "\"];" << endl;
  travelChildren(node, level);
}

void travelChildren(struct Node* node, int level) {
	for(int i = 0; i < node -> children.size(); i++) {
		cout << "\t\tn" << level << " -> " << "n" << level << "_" << i << ";" << endl;
		printNode(node->children[i], (level + 1));
	}
}

int main() {
  if (!yylex()) {
    int level = 0;
    cout << "digraph G {" << endl;
    printNode(root, level);
    cout << "}" << endl;
  }
  return 0;
}
