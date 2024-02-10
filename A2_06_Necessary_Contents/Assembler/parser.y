%code requires {
	#include <iostream>
	#include <fstream>
}
%define api.value.type {std::string}

%{
#include <iostream>
#include <sstream>
#include <cstdlib>
#include <map>
#include <vector>

int yylex(void);
extern FILE *yyin;
void yyerror(const char *message);

int getOpcodeID(std::string opcode);
int getRegisterID(std::string reg);
char getHexChar(int number);
void writeBin(std::ofstream &out, std::string str);

std::string isa;

int instructionCounter = 0;
std::map<std::string, int> map;

std::stringstream instructionBuffer;
std::vector<std::string> instructions;

%}

%token ADD ADDI SUB SUBI AND ANDI OR ORI SLL SRL NOR SW LW BEQ BNEQ J REGISTER COMMA COLON LPAREN RPAREN LABEL INT PUSH POP
%type start program unit instruction rtype_instruction rtype_params itype_instruction itype_params branch_params memory_params stype_instruction jtype_instruction labels

%%
start: program {

	char beqCode =  getHexChar(getOpcodeID("beq"));
	char bneqCode =  getHexChar(getOpcodeID("bneq"));
	char jCode = getHexChar(getOpcodeID("j"));

	int index = 0;
	for (auto i = instructions.begin(); i != instructions.end(); ++i, ++index) {
		std::string &instruction = *i;
		if (instruction[0] == beqCode || instruction[0] == bneqCode) {
			std::string label = instruction.substr(3);
			int destination = map[label];
			int offset = destination - index - 1;
			int signedOffset = (16 + offset) % 16;

			instruction = instruction.substr(0, 3) + getHexChar(signedOffset);
		}
		else if (instruction[0] == jCode) {
			std::string label = instruction.substr(1);
			int destination = map[label];
			instruction = std::string("") + instruction[0] + getHexChar((destination >> 4) & 0xF) + getHexChar(destination & 0xF) + "0";
		}
	}
}
;
program: program unit
	|
	unit
;
unit: instruction { ++instructionCounter; }
	|
	labels instruction { ++instructionCounter; }
;

labels: labels LABEL { map[$2] = instructionCounter; } COLON
	|
	LABEL { map[$1] = instructionCounter; } COLON
;

instruction: rtype_instruction
	|
	itype_instruction
	|
	stype_instruction
	|
	jtype_instruction
	|
	push_instruction
	|
	pop_instruction
;

rtype_instruction: ADD { instructionBuffer << getHexChar(getOpcodeID("add")); } rtype_params
	|
	SUB { instructionBuffer << getHexChar(getOpcodeID("sub")); } rtype_params
	|
	AND { instructionBuffer << getHexChar(getOpcodeID("and")); } rtype_params
	|
	OR { instructionBuffer << getHexChar(getOpcodeID("or")); } rtype_params
	|
	NOR { instructionBuffer << getHexChar(getOpcodeID("nor")); } rtype_params
;

rtype_params: REGISTER COMMA REGISTER COMMA REGISTER {
	instructionBuffer << getHexChar(getRegisterID($3)) << getHexChar(getRegisterID($5)) << getHexChar(getRegisterID($1));
	instructions.push_back(instructionBuffer.str());
	instructionBuffer.str(std::string());
}
;

itype_instruction: ADDI { instructionBuffer << getHexChar(getOpcodeID("addi")); } itype_params
	|
	SUBI { instructionBuffer << getHexChar(getOpcodeID("subi")); } itype_params
	|
	ANDI { instructionBuffer << getHexChar(getOpcodeID("andi")); } itype_params
	|
	ORI { instructionBuffer << getHexChar(getOpcodeID("ori")); } itype_params
	|
	BEQ { instructionBuffer << getHexChar(getOpcodeID("beq")); } branch_params
	|
	BNEQ { instructionBuffer << getHexChar(getOpcodeID("bneq")); } branch_params
	|
	LW { instructionBuffer << getHexChar(getOpcodeID("lw")); } memory_params
	|
	SW { instructionBuffer << getHexChar(getOpcodeID("sw")); } memory_params
;

itype_params: REGISTER COMMA REGISTER COMMA INT {
	instructionBuffer << getHexChar(getRegisterID($3)) << getHexChar(getRegisterID($1)) << getHexChar(atoi($5.c_str()));
	instructions.push_back(instructionBuffer.str());
	instructionBuffer.str(std::string());
}
;

branch_params: REGISTER COMMA REGISTER COMMA LABEL {
	instructionBuffer << getHexChar(getRegisterID($1)) << getHexChar(getRegisterID($3)) << $5;
	instructions.push_back(instructionBuffer.str());
	instructionBuffer.str(std::string());
}
;

memory_params: REGISTER COMMA INT LPAREN REGISTER RPAREN {
	instructionBuffer << getHexChar(getRegisterID($5)) << getHexChar(getRegisterID($1)) << getHexChar(atoi($3.c_str()));
	instructions.push_back(instructionBuffer.str());
	instructionBuffer.str(std::string());
}
;

stype_instruction: SLL { instructionBuffer << getHexChar(getOpcodeID("sll")); } itype_params
	|
	SRL { instructionBuffer << getHexChar(getOpcodeID("srl")); } itype_params
;

jtype_instruction: J { instructionBuffer << getHexChar(getOpcodeID("j")); } LABEL {
	instructionBuffer << $3;
	instructions.push_back(instructionBuffer.str());
	instructionBuffer.str(std::string());
}
;

push_instruction: PUSH REGISTER {
	instructionBuffer << getHexChar(getOpcodeID("sw")) << getHexChar(getRegisterID("$sp")) << getHexChar(getRegisterID($2)) << "0";
	instructions.push_back(instructionBuffer.str());
	instructionBuffer.str(std::string());
	
	instructionBuffer << getHexChar(getOpcodeID("subi")) << getHexChar(getRegisterID("$sp")) << getHexChar(getRegisterID("$sp")) << "1";
	instructions.push_back(instructionBuffer.str());
	instructionBuffer.str(std::string());

	++instructionCounter;
}
	|
	PUSH INT LPAREN REGISTER RPAREN {
		instructionBuffer << getHexChar(getOpcodeID("lw")) << getHexChar(getRegisterID($4)) << getHexChar(getRegisterID("$x0")) << getHexChar(atoi($2.c_str()));
		instructions.push_back(instructionBuffer.str());
		instructionBuffer.str(std::string());

		instructionBuffer << getHexChar(getOpcodeID("sw")) << getHexChar(getRegisterID("$sp")) << getHexChar(getRegisterID("$x0")) << "0";
		instructions.push_back(instructionBuffer.str());
		instructionBuffer.str(std::string());
		
		instructionBuffer << getHexChar(getOpcodeID("subi")) << getHexChar(getRegisterID("$sp")) << getHexChar(getRegisterID("$sp")) << "1";
		instructions.push_back(instructionBuffer.str());
		instructionBuffer.str(std::string());

		instructionCounter += 2;
	}
;

pop_instruction: POP REGISTER {
	instructionBuffer << getHexChar(getOpcodeID("addi")) << getHexChar(getRegisterID("$sp")) << getHexChar(getRegisterID("$sp")) << "1";
	instructions.push_back(instructionBuffer.str());
	instructionBuffer.str(std::string());
	
	instructionBuffer << getHexChar(getOpcodeID("lw")) << getHexChar(getRegisterID("$sp")) << getHexChar(getRegisterID($2)) << "0";
	instructions.push_back(instructionBuffer.str());
	instructionBuffer.str(std::string());

	++instructionCounter;
}
;

%%

int main(int argc, char **argv) {
	if (argc != 3 && argc != 4) {
		std::cout << "Wrong usage" << std::endl;
		std::cout << "Sample usage: ./assembler.out [--safe-init] <assembly_file_path> <isa_string>" << std::endl;
		return 1;
	}

	isa = argv[argc == 3? 2 : 3];

	yyin = fopen(argv[argc == 3? 1 : 2], "r");
	if (!yyin) {
		std::cout << "File not found" << std::endl;
		return 1;
	}

	if (argc == 4) {
		if (std::string(argv[1]) == "--safe-init") {
			// clear $zero by performing $zero = $zero sub $zero
			instructionBuffer << getHexChar(getOpcodeID("sub")) << getHexChar(getRegisterID("$zero")) << getHexChar(getRegisterID("$zero")) << getHexChar(getRegisterID("$zero"));
			instructions.insert(instructions.begin(), instructionBuffer.str());
			instructionBuffer.str(std::string());

			//set $sp to F by performing $sp = $sp | 0xF
			instructionBuffer << getHexChar(getOpcodeID("ori")) << getHexChar(getRegisterID("$sp")) << getHexChar(getRegisterID("$sp")) << "F";
			instructions.insert(instructions.begin(), instructionBuffer.str());
			instructionBuffer.str(std::string());
		} else {
			std::cout << "unknown flag " << argv[1] << std::endl;
			exit(1);
		}

		instructionCounter += 2;

	}

	yyparse();


	std::ofstream hexFile("hex.txt");
	std::ofstream binFile("out.bin");
	for (auto i = instructions.begin(); i != instructions.end(); ++i) {
		hexFile << *i << std::endl;
		writeBin(binFile, *i);
	}
	hexFile.close();

	fclose(yyin);
	return 0;
}

void yyerror(const char *message) {
	std::cout << "syntax error: " << message << std::endl;
}

int getOpcodeID(std::string opcode) {
	std::string list[] = {"add", "addi", "sub", "subi", "and", "andi", "or", "ori", "sll", "srl", "nor", "sw", "lw", "beq", "bneq", "j"};

	int index = -1;
	for (int i = 0; i < isa.length(); ++i) {
		if (list[i] == opcode) {
			index = i;
			break;
		}
	}

	if (index == -1) {
		std::cout << "could not find " << opcode << std::endl;
		exit(1);
	}

	char idChar = 'A' + index;

	return isa.find(idChar);
}

int getRegisterID(std::string reg) {
	if (reg == "$zero") return 0;
	else if (reg == "$t0") return 1;
	else if (reg == "$t1") return 2;
	else if (reg == "$t2") return 3;
	else if (reg == "$t3") return 4;
	else if (reg == "$t4") return 5;
	else if (reg == "$sp") return 6;
	else if (reg == "$x0") return 7;
	else {
		std::cout <<c"Cannot find register id for " << reg << std::endl;
		exit(1);
	}
}

char getHexChar(int number) {
	return number < 10? '0' + number : number - 10 + 'A';
}

int getDec(char hex) {
	return isalpha(hex)? hex - 'A' + 10: hex - '0';
}

void writeBin(std::ofstream &out, std::string str) {
	unsigned char x = getDec(str[0]) * 16 + getDec(str[1]);
	unsigned char y = getDec(str[2]) * 16 + getDec(str[3]);
	out << x << y;
}
