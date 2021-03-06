import dart.core {
    DIterator = Iterator,
    DIteratorClass = Iterator_C
}
import dart.collection {
    DIterableBaseClass = IterableBase_C
}

shared
class DartIterable<Element>({Element*} elements)
        extends DIterableBaseClass<Element>() {

    shared actual
    DIterator<Element> iterator => object extends DIteratorClass<Element>() {
        Iterator<Element> iterator = elements.iterator();

        variable Element? currentElement = null;

        shared actual
        Element? current => currentElement;

        // FIXME current wasn't supposed to be variable...
        assign current {
        }

        shared actual
        Boolean moveNext() {
            switch (next = iterator.next())
            case (finished) {
                currentElement = null;
                return false;
            }
            else {
                currentElement = next;
                return true;
            }
        }
    };

    assign iterator {}
}
