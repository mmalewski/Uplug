///////////////////////////////////////////////////////////////////////////////
// Copyright (C) 2002 Jason Baldridge
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; either
// version 2.1 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
// 
// You should have received a copy of the GNU Lesser General Public
// License along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
//////////////////////////////////////////////////////////////////////////////

package opennlp.grok.unify;

import opennlp.grok.expression.*;
import opennlp.common.synsem.*;
import opennlp.common.unify.*;

/**
 * A unifier for Grok categories.
 *
 * @author      Jason Baldridge
 * @version     $Revision$, $Date$
 */
public class GUnifier { 


    public static Category unify (Category c1, Category c2)
	throws UnifyFailure {
	return (Category)Unifier.unify(c1, c2, new EmptySubstitution());
    }

    public static Category unify (Category c1, Category c2, Substitution sub)
	throws UnifyFailure {
	return (Category)Unifier.unify(c1, c2, sub);
	//if (c1 instanceof CurriedCat && c2 instanceof CurriedCat) {
	    
	//}
	
    }
    
}
