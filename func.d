module func;

string passArguments (string func)
{
	return "switch (_arguments.length)
	{
		case 0:
			" ~ func ~ "();
			break;
		case 1:
			" ~ func ~ "(_arguments[0]);
			break;
		case 2:
			" ~ func ~ "(_arguments[0], _arguments[1]);
			break;
		case 3:
			" ~ func ~ "(_arguments[0], _arguments[1], _arguments[2]);
			break;
		case 4:
			" ~ func ~ "(_arguments[0], _arguments[1], _arguments[2], _arguments[3]);
			break;
		case 5:
			" ~ func ~ "(_arguments[0], _arguments[1], _arguments[2], _arguments[3], _arguments[4]);
			break;
		case 6:
			" ~ func ~ "(_arguments[0], _arguments[1], _arguments[2], _arguments[3], _arguments[4], _arguments[5]);
			break;
		case 7:
			" ~ func ~ "(_arguments[0], _arguments[1], _arguments[2], _arguments[3], _arguments[4], _arguments[5], _arguments[6]);
			break;
		case 8:
			" ~ func ~ "(_arguments[0], _arguments[1], _arguments[2], _arguments[3], _arguments[4], _arguments[5], _arguments[6], _arguments[7]);
			break;
		default:
			throw new Exception(\"not implemented\");
	}";
}
